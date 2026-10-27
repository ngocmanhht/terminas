import Foundation

public struct SSHAuthPreparation: Sendable {
    public let environment: [String: String]
    public let tempFile: URL?
    public let extraArgs: [String]
    
    public init(environment: [String: String], tempFile: URL?, extraArgs: [String]) {
        self.environment = environment
        self.tempFile = tempFile
        self.extraArgs = extraArgs
    }
}

public enum SSHAuthHelper {
    public static var helperScriptURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Terminas", isDirectory: true)
        return appSupport.appendingPathComponent("terminas-askpass.sh")
    }
    
    /// Ensures the native askpass helper script exists and has 0700 execution permissions
    public static func ensureHelperInstalled() {
        let fileURL = helperScriptURL
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        
        let script = """
        #!/bin/sh
        # Terminas SSH Native AskPass Helper
        PROMPT="$1"

        # 1. Automatic host key fingerprint acceptance (yes/no)
        case "$PROMPT" in
            *"yes/no"*)
                echo "yes"
                exit 0
                ;;
        esac

        # 2. Multi-host / Bastion pass mapping
        if [ -n "$TERMINAS_PASS_MAP" ] && [ -r "$TERMINAS_PASS_MAP" ]; then
            while IFS='=' read -r hostkey passval; do
                case "$PROMPT" in
                    *"$hostkey"*)
                        printf "%s" "$passval"
                        exit 0
                        ;;
                esac
            done < "$TERMINAS_PASS_MAP"
            
            # Fallback to last password in map if prompt is generic (e.g. "Password:")
            if [ -n "$passval" ]; then
                printf "%s" "$passval"
                exit 0
            fi
        fi

        # 3. Target host password file: Read repeatedly during handshake without early deletion
        if [ -n "$TERMINAS_PASS_FILE" ] && [ -r "$TERMINAS_PASS_FILE" ]; then
            cat "$TERMINAS_PASS_FILE"
            exit 0
        fi

        exit 1
        """
        
        try? script.write(to: fileURL, atomically: true, encoding: .utf8)
        chmod(fileURL.path, S_IRWXU)
    }
    
    /// Prepares environment and SSH args for an SSH session
    public static func prepareAuth(
        for host: HostItem,
        jumpHost: HostItem? = nil,
        oneTime: Bool = true,
        baseEnv: [String: String] = ProcessInfo.processInfo.environment
    ) -> SSHAuthPreparation {
        ensureHelperInstalled()
        
        var env = baseEnv
        var extraArgs: [String] = []
        var tempFileURL: URL? = nil
        
        let hostPassword = KeychainService.getPassword(for: host.id)
        let jumpPassword = jumpHost.flatMap { KeychainService.getPassword(for: $0.id) }
        
        let hasPassword = (hostPassword?.isEmpty == false) || (jumpPassword?.isEmpty == false)
        
        if hasPassword {
            let helperPath = helperScriptURL.path
            env["SSH_ASKPASS"] = helperPath
            env["SSH_ASKPASS_REQUIRE"] = "force"
            env["DISPLAY"] = ":0"
            
            // Prefer password & keyboard-interactive when password auth is selected
            if host.authType == .password {
                extraArgs.append(contentsOf: [
                    "-o", "PreferredAuthentications=password,keyboard-interactive",
                    "-o", "PubkeyAuthentication=no"
                ])
            }
            
            // Dual Bastion Jump Host + Target Host mapping
            if let jp = jumpPassword, !jp.isEmpty, let jh = jumpHost, let hp = hostPassword, !hp.isEmpty {
                let mapString = "\(jh.hostname)=\(jp)\n\(host.hostname)=\(hp)\n"
                let tmpMap = FileManager.default.temporaryDirectory.appendingPathComponent("terminas_map_\(UUID().uuidString).dat")
                if let data = mapString.data(using: .utf8) {
                    try? data.write(to: tmpMap, options: .atomic)
                    chmod(tmpMap.path, S_IRUSR | S_IWUSR)
                    env["TERMINAS_PASS_MAP"] = tmpMap.path
                    tempFileURL = tmpMap
                }
            } else if let hp = hostPassword, !hp.isEmpty {
                let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent("terminas_pass_\(UUID().uuidString).dat")
                if let data = hp.data(using: .utf8) {
                    try? data.write(to: tmpFile, options: .atomic)
                    chmod(tmpFile.path, S_IRUSR | S_IWUSR)
                    env["TERMINAS_PASS_FILE"] = tmpFile.path
                    tempFileURL = tmpFile
                }
            } else if let jp = jumpPassword, !jp.isEmpty {
                let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent("terminas_pass_\(UUID().uuidString).dat")
                if let data = jp.data(using: .utf8) {
                    try? data.write(to: tmpFile, options: .atomic)
                    chmod(tmpFile.path, S_IRUSR | S_IWUSR)
                    env["TERMINAS_PASS_FILE"] = tmpFile.path
                    tempFileURL = tmpFile
                }
            }
        }
        
        return SSHAuthPreparation(
            environment: env,
            tempFile: tempFileURL,
            extraArgs: extraArgs
        )
    }
}
