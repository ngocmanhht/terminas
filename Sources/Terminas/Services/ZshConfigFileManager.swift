import Foundation
import Combine

@MainActor
public class ZshConfigFileManager: ObservableObject {
    @Published public var activeFile: ShellFileTarget = .zshrc
    @Published public var rawContent: String = ""
    @Published public var envVariables: [ZshEnvItem] = []
    @Published public var aliases: [ZshAliasItem] = []
    @Published public var pathEntries: [ZshPathItem] = []
    @Published public var plugins: [ZshPluginItem] = []
    
    @Published public var errorMessage: String? = nil
    @Published public var successMessage: String? = nil
    @Published public var syntaxCheckResult: String? = nil
    @Published public var isSyntaxValid: Bool = true
    
    public init() {
        load(target: .zshrc)
    }
    
    public var currentFileURL: URL {
        activeFile.fileURL
    }
    
    public func selectFile(_ target: ShellFileTarget) {
        self.activeFile = target
        load(target: target)
    }
    
    public func load(target: ShellFileTarget? = nil) {
        if let target = target {
            self.activeFile = target
        }
        
        let url = currentFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            self.rawContent = "# \(activeFile.rawValue) - Managed by Terminas\n\n"
            self.envVariables = []
            self.aliases = []
            self.pathEntries = []
            self.plugins = []
            return
        }
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            self.rawContent = content
            parseContent(content)
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Failed to load \(activeFile.rawValue): \(error.localizedDescription)"
        }
    }
    
    // MARK: - Save Operations
    public func saveRaw(_ newContent: String, createBackup: Bool = true) -> Bool {
        let url = currentFileURL
        
        if createBackup && FileManager.default.fileExists(atPath: url.path) {
            let backupURL = url.deletingPathExtension().appendingPathExtension("bak")
            try? FileManager.default.copyItem(at: url, to: backupURL)
        }
        
        do {
            try newContent.write(to: url, atomically: true, encoding: .utf8)
            self.rawContent = newContent
            parseContent(newContent)
            self.errorMessage = nil
            self.successMessage = "Saved \(activeFile.rawValue) successfully!"
            testSyntax()
            return true
        } catch {
            self.errorMessage = "Failed to save: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Environment Variables
    public func addOrUpdateEnv(key: String, value: String, isExported: Bool = true) -> Bool {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else { return false }
        
        let prefix = isExported ? "export " : ""
        let quote = value.contains(" ") || value.contains("$") ? "\"" : ""
        let newLine = "\(prefix)\(cleanKey)=\(quote)\(value)\(quote)"
        
        var lines = rawContent.components(separatedBy: "\n")
        var foundIndex: Int? = nil
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("export \(cleanKey)=") || trimmed.hasPrefix("\(cleanKey)=") {
                foundIndex = index
                break
            }
        }
        
        if let idx = foundIndex {
            lines[idx] = newLine
        } else {
            lines.append("\n# Added by Terminas")
            lines.append(newLine)
        }
        
        return saveRaw(lines.joined(separator: "\n"))
    }
    
    public func deleteEnv(key: String) -> Bool {
        var lines = rawContent.components(separatedBy: "\n")
        lines.removeAll { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("export \(key)=") || trimmed.hasPrefix("\(key)=")
        }
        return saveRaw(lines.joined(separator: "\n"))
    }
    
    // MARK: - Aliases
    public func addOrUpdateAlias(name: String, command: String) -> Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return false }
        
        let newLine = "alias \(cleanName)='\(command)'"
        var lines = rawContent.components(separatedBy: "\n")
        var foundIndex: Int? = nil
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("alias \(cleanName)=") {
                foundIndex = index
                break
            }
        }
        
        if let idx = foundIndex {
            lines[idx] = newLine
        } else {
            lines.append("\n# Alias added by Terminas")
            lines.append(newLine)
        }
        
        return saveRaw(lines.joined(separator: "\n"))
    }
    
    public func deleteAlias(name: String) -> Bool {
        var lines = rawContent.components(separatedBy: "\n")
        lines.removeAll { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("alias \(name)=")
        }
        return saveRaw(lines.joined(separator: "\n"))
    }
    
    // MARK: - PATH Management
    public func addPathEntry(directory: String) -> Bool {
        let cleanDir = directory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanDir.isEmpty else { return false }
        
        var lines = rawContent.components(separatedBy: "\n")
        lines.append("\n# PATH entry added by Terminas")
        lines.append("export PATH=\"\(cleanDir):$PATH\"")
        return saveRaw(lines.joined(separator: "\n"))
    }
    
    // MARK: - Plugins Management (Oh My Zsh plugins=(...))
    public func addPlugin(name: String) -> Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return false }
        if plugins.contains(where: { $0.name == cleanName }) { return true }
        
        let pattern = #"(?s)plugins\s*=\s*\((.*?)\)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: rawContent, options: [], range: NSRange(location: 0, length: (rawContent as NSString).length)) {
            
            let insideRange = match.range(at: 1)
            let insideText = (rawContent as NSString).substring(with: insideRange)
            let isMultiline = insideText.contains("\n")
            
            let replacement: String
            if isMultiline {
                var trimmedInside = insideText
                if trimmedInside.hasSuffix("\n") {
                    trimmedInside.removeLast()
                }
                replacement = "\(trimmedInside)\n  \(cleanName)\n"
            } else {
                let trimmedInside = insideText.trimmingCharacters(in: .whitespaces)
                if trimmedInside.isEmpty {
                    replacement = cleanName
                } else {
                    replacement = "\(trimmedInside) \(cleanName)"
                }
            }
            
            let newRaw = (rawContent as NSString).replacingCharacters(in: insideRange, with: replacement)
            return saveRaw(newRaw)
        } else {
            var lines = rawContent.components(separatedBy: "\n")
            lines.append("\n# Oh My Zsh plugins managed by Terminas")
            lines.append("plugins=(\n  \(cleanName)\n)")
            return saveRaw(lines.joined(separator: "\n"))
        }
    }
    
    public func removePlugin(name: String) -> Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return false }
        
        let pattern = #"(?s)plugins\s*=\s*\((.*?)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: rawContent, options: [], range: NSRange(location: 0, length: (rawContent as NSString).length)) else {
            return false
        }
        
        let insideRange = match.range(at: 1)
        let insideText = (rawContent as NSString).substring(with: insideRange)
        
        let lines = insideText.components(separatedBy: "\n")
        var modifiedLines: [String] = []
        for line in lines {
            let tokens = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if tokens.contains(cleanName) {
                let filteredTokens = tokens.filter { $0 != cleanName }
                if filteredTokens.isEmpty {
                    continue
                } else {
                    modifiedLines.append("  " + filteredTokens.joined(separator: " "))
                }
            } else {
                modifiedLines.append(line)
            }
        }
        let newInside = modifiedLines.joined(separator: "\n")
        let newRaw = (rawContent as NSString).replacingCharacters(in: insideRange, with: newInside)
        return saveRaw(newRaw)
    }
    
    private func parsePlugins(from text: String) -> [ZshPluginItem] {
        let pattern = #"(?s)plugins\s*=\s*\((.*?)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let nsString = text as NSString
        let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var pluginList: [ZshPluginItem] = []
        for match in results {
            if match.numberOfRanges >= 2 {
                let insideRange = match.range(at: 1)
                let insideText = nsString.substring(with: insideRange)
                
                for line in insideText.components(separatedBy: "\n") {
                    let cleanedLine = line.components(separatedBy: "#").first ?? ""
                    for token in cleanedLine.components(separatedBy: .whitespaces) {
                        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty && !pluginList.contains(where: { $0.name == trimmed }) {
                            pluginList.append(ZshPluginItem(name: trimmed))
                        }
                    }
                }
            }
        }
        return pluginList
    }
    
    // MARK: - Syntax Check
    public func testSyntax() {
        let path = currentFileURL.path
        guard FileManager.default.fileExists(atPath: path) else {
            self.syntaxCheckResult = "File does not exist on disk yet."
            self.isSyntaxValid = true
            return
        }
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-n", path]
        
        let pipe = Pipe()
        proc.standardError = pipe
        proc.standardOutput = pipe
        
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if proc.terminationStatus == 0 {
                self.isSyntaxValid = true
                self.syntaxCheckResult = "Syntax OK (zsh -n passed without errors)"
            } else {
                self.isSyntaxValid = false
                self.syntaxCheckResult = output.isEmpty ? "Syntax error detected (exit code \(proc.terminationStatus))" : output
            }
        } catch {
            self.syntaxCheckResult = "Syntax check skipped: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Parsing Logic
    private func parseContent(_ text: String) {
        var envs: [ZshEnvItem] = []
        var aliasList: [ZshAliasItem] = []
        var pathDirs: Set<String> = []
        var orderedPaths: [ZshPathItem] = []
        
        let lines = text.components(separatedBy: "\n")
        var inMultilineArray = false
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            
            // Skip inside multiline arrays like plugins=( ... )
            if inMultilineArray {
                if trimmed.contains(")") {
                    inMultilineArray = false
                }
                continue
            }
            if (trimmed.contains("=(") || trimmed.contains("= (")) && !trimmed.contains(")") {
                inMultilineArray = true
                continue
            }
            
            // 1. Check for Aliases: alias name='command' or alias name="command"
            if trimmed.hasPrefix("alias ") {
                let rest = String(trimmed.dropFirst(6))
                if let eqIndex = rest.firstIndex(of: "=") {
                    let name = String(rest[..<eqIndex]).trimmingCharacters(in: .whitespaces)
                    var cmd = String(rest[rest.index(after: eqIndex)...]).trimmingCharacters(in: .whitespaces)
                    if (cmd.hasPrefix("\"") && cmd.hasSuffix("\"")) || (cmd.hasPrefix("'") && cmd.hasSuffix("'")) {
                        cmd = String(cmd.dropFirst().dropLast())
                    }
                    if !name.isEmpty {
                        aliasList.append(ZshAliasItem(name: name, command: cmd, lineNumber: index + 1))
                    }
                }
                continue
            }
            
            // 2. Check for PATH: export PATH=... or PATH=...
            if trimmed.contains("PATH=") {
                let parts = trimmed.components(separatedBy: "PATH=")
                if parts.count >= 2 {
                    let val = parts[1].replacingOccurrences(of: "\"", with: "")
                        .replacingOccurrences(of: "'", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    for seg in val.components(separatedBy: ":") {
                        let dir = seg.trimmingCharacters(in: .whitespaces)
                        if !dir.isEmpty && dir != "$PATH" && !pathDirs.contains(dir) {
                            pathDirs.insert(dir)
                            let expanded = (dir as NSString).expandingTildeInPath
                            let exists = FileManager.default.fileExists(atPath: expanded)
                            orderedPaths.append(ZshPathItem(directory: dir, existsOnDisk: exists))
                        }
                    }
                }
            }
            
            // 3. Check for Environment Variables: export KEY=VAL or KEY=VAL
            var isExported = false
            var candidate = trimmed
            if candidate.hasPrefix("export ") {
                isExported = true
                candidate = String(candidate.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            }
            
            if let eqIndex = candidate.firstIndex(of: "=") {
                let key = String(candidate[..<eqIndex]).trimmingCharacters(in: .whitespaces)
                var val = String(candidate[candidate.index(after: eqIndex)...]).trimmingCharacters(in: .whitespaces)
                
                // Exclude arrays (plugins=(...)), bash internal variables, or PATH
                if key != "PATH" && key != "plugins" && !val.hasPrefix("(") && !key.contains(" ") && isValidEnvKey(key) {
                    if (val.hasPrefix("\"") && val.hasSuffix("\"")) || (val.hasPrefix("'") && val.hasSuffix("'")) {
                        val = String(val.dropFirst().dropLast())
                    }
                    envs.append(ZshEnvItem(key: key, value: val, isExported: isExported, lineNumber: index + 1))
                }
            }
        }
        
        // Also capture current system $PATH if empty in file
        if orderedPaths.isEmpty, let sysPath = ProcessInfo.processInfo.environment["PATH"] {
            for seg in sysPath.components(separatedBy: ":") {
                let dir = seg.trimmingCharacters(in: .whitespaces)
                if !dir.isEmpty && !pathDirs.contains(dir) {
                    pathDirs.insert(dir)
                    let exists = FileManager.default.fileExists(atPath: dir)
                    orderedPaths.append(ZshPathItem(directory: dir, existsOnDisk: exists))
                }
            }
        }
        
        self.envVariables = envs
        self.aliases = aliasList
        self.pathEntries = orderedPaths
        self.plugins = parsePlugins(from: text)
    }
    
    private func isValidEnvKey(_ str: String) -> Bool {
        guard let first = str.first, first.isLetter || first == "_" else { return false }
        for ch in str {
            if !ch.isLetter && !ch.isNumber && ch != "_" { return false }
        }
        return true
    }
}
