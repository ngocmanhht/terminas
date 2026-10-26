import SwiftUI
import AppKit

public struct SFTPBrowserView: View {
    @EnvironmentObject private var hostStore: HostStore
    @EnvironmentObject private var navManager: AppNavigationManager
    @EnvironmentObject private var sessionManager: TerminalSessionManager
    @StateObject private var sftp = SFTPService()
    
    @State private var selectedHostId: UUID? = nil
    @State private var pathInput: String = ""
    @State private var selectedFileID: RemoteFileItem.ID? = nil
    @State private var previewFile: RemoteFileItem? = nil
    @State private var previewContent: String = ""
    @State private var isShowingNewFolderDialog = false
    @State private var newFolderName = ""
    @State private var isDropTarget = false
    
    public init() {}
    
    private var selectedHost: HostItem? {
        if let id = selectedHostId {
            return hostStore.hosts.first { $0.id == id }
        }
        return hostStore.hosts.first
    }
    
    private var jumpHost: HostItem? {
        guard let jid = selectedHost?.jumpHostId else { return nil }
        return hostStore.hosts.first { $0.id == jid }
    }
    
    private struct PathSegment: Identifiable {
        let id: String
        let name: String
        let fullPath: String
        let isLast: Bool
    }
    
    private var pathSegments: [PathSegment] {
        let path = sftp.currentPath
        guard !path.isEmpty else { return [] }
        let rawParts = path.split(separator: "/").map(String.init)
        var result: [PathSegment] = []
        result.append(PathSegment(id: "/", name: "root", fullPath: "/", isLast: rawParts.isEmpty))
        
        var accumulated = ""
        for (idx, part) in rawParts.enumerated() {
            accumulated += "/" + part
            result.append(PathSegment(
                id: accumulated,
                name: part,
                fullPath: accumulated,
                isLast: idx == rawParts.count - 1
            ))
        }
        return result
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Bar: Host Selector & Actions
            HStack(spacing: 12) {
                // Host Selector
                Picker("Host:", selection: Binding(
                    get: { selectedHost?.id ?? UUID() },
                    set: { newId in
                        selectedHostId = newId
                        if let h = hostStore.hosts.first(where: { $0.id == newId }) {
                            sftp.listDirectory(host: h, path: "")
                        }
                    }
                )) {
                    ForEach(hostStore.hosts) { h in
                        Text(h.displayTitle).tag(h.id)
                    }
                }
                .frame(width: 240)
                
                Divider().frame(height: 16)
                
                // Navigation buttons
                Button(action: goUp) {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.plain)
                .help("Go to parent directory")
                .disabled(sftp.currentPath == "/" || sftp.isLoading)
                
                Button(action: {
                    if let host = selectedHost {
                        sftp.listDirectory(host: host, path: "~")
                    }
                }) {
                    Image(systemName: "house")
                }
                .buttonStyle(.plain)
                .help("Go to home directory")
                
                // Path Input Field
                HStack {
                    Image(systemName: "folder")
                        .foregroundColor(.secondary)
                    TextField("Remote path", text: $pathInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .onSubmit {
                            if let host = selectedHost {
                                sftp.listDirectory(host: host, path: pathInput)
                            }
                        }
                    
                    if sftp.isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.6)
                    } else {
                        Button(action: {
                            if let host = selectedHost {
                                sftp.listDirectory(host: host, path: sftp.currentPath)
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .help("Refresh")
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                
                // Actions
                Button(action: { isShowingNewFolderDialog = true }) {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)
                
                Button(action: uploadFilePrompt) {
                    Label("Upload", systemImage: "arrow.up.doc")
                }
                .buttonStyle(.borderedProminent)
            }
            .detailHeaderPadding(defaultLeading: 0, collapsedLeading: 108)
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 6)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Interactive Breadcrumb Navigation
            HStack(spacing: 6) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 3) {
                        ForEach(pathSegments) { seg in
                            Button(action: {
                                if let host = selectedHost {
                                    pathInput = seg.fullPath
                                    sftp.listDirectory(host: host, path: seg.fullPath)
                                }
                            }) {
                                HStack(spacing: 2) {
                                    Text(seg.name)
                                        .font(.system(size: 11, weight: seg.isLast ? .semibold : .regular))
                                }
                                .foregroundColor(seg.isLast ? .accentColor : .primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(seg.isLast ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
                                )
                            }
                            .buttonStyle(.plain)
                            .help("Jump to \(seg.fullPath)")
                            
                            if !seg.isLast {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.secondary.opacity(0.4))
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Active Transfer Banner
            if let transfer = sftp.activeTransfer {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.8)
                    Text(transfer)
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.12))
            }
            
            // Error banner if any
            if let error = sftp.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
            }
            
            // File List Table with Drag & Drop Zone
            ZStack {
                if sftp.files.isEmpty && !sftp.isLoading {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "folder")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Directory is Empty")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Drag & drop files from Finder here to upload")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.8))
                        Spacer()
                    }
                } else {
                    Table(sftp.files, selection: $selectedFileID) {
                        TableColumn("Name") { (file: RemoteFileItem) -> FileRowCell in
                            FileRowCell(file: file) {
                                handleDoubleTap(file)
                            }
                        }
                        
                        TableColumn("Size") { (file: RemoteFileItem) -> Text in
                            Text(file.formattedSize)
                        }
                        .width(min: 80, ideal: 100, max: 120)
                        
                        TableColumn("Permissions") { (file: RemoteFileItem) -> Text in
                            Text(file.permissions)
                        }
                        .width(min: 90, ideal: 110, max: 130)
                        
                        TableColumn("Modified") { (file: RemoteFileItem) -> Text in
                            Text(file.modifiedDate)
                        }
                        .width(min: 130, ideal: 150, max: 180)
                    }
                    .contextMenu(forSelectionType: RemoteFileItem.ID.self) { items in
                        fileContextMenu(for: items)
                    }
                }
                
                // Drop Target Overlay
                if isDropTarget {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.accentColor.opacity(0.08))
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2.5, dash: [8, 5]))
                        
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.accentColor)
                            Text("Drop files to upload to \(sftp.currentPath)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(12)
                    .allowsHitTesting(false)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTarget) { providers in
                handleDrop(providers: providers)
            }
        }
        .onAppear {
            applyTargetHostIfNeeded()
        }
        .onChange(of: navManager.sftpTargetHostId) { _, _ in
            applyTargetHostIfNeeded()
        }
        .onChange(of: sftp.currentPath) { _, newPath in
            pathInput = newPath
        }
        .sheet(item: $previewFile) { file in
            FilePreviewSheet(file: file, content: previewContent)
        }
        .sheet(isPresented: $isShowingNewFolderDialog) {
            VStack(spacing: 16) {
                Text("Create New Directory")
                    .font(.headline)
                TextField("Folder Name", text: $newFolderName)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("Cancel") {
                        isShowingNewFolderDialog = false
                        newFolderName = ""
                    }
                    Button("Create") {
                        if let host = selectedHost, !newFolderName.isEmpty {
                            let name = newFolderName
                            isShowingNewFolderDialog = false
                            newFolderName = ""
                            Task {
                                _ = await sftp.createDirectory(host: host, folderName: name)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding()
            .frame(width: 320)
        }
    }
    
    private func applyTargetHostIfNeeded() {
        guard let targetId = navManager.sftpTargetHostId else { return }
        if let h = hostStore.hosts.first(where: { $0.id == targetId }) {
            selectedHostId = targetId
            let jh = h.jumpHostId.flatMap { jid in hostStore.hosts.first(where: { $0.id == jid }) }
            sftp.listDirectory(host: h, jumpHost: jh, path: "")
        }
        navManager.sftpTargetHostId = nil
    }
    
    private func goUp() {
        let parent = (sftp.currentPath as NSString).deletingLastPathComponent
        if let host = selectedHost {
            sftp.listDirectory(host: host, jumpHost: jumpHost, path: parent.isEmpty ? "/" : parent)
        }
    }
    
    private func handleDoubleTap(_ file: RemoteFileItem) {
        if file.isDirectory {
            if let host = selectedHost {
                sftp.listDirectory(host: host, jumpHost: jumpHost, path: file.path)
            }
        } else {
            openPreview(file)
        }
    }
    
    private func openPreview(_ file: RemoteFileItem) {
        guard let host = selectedHost else { return }
        Task {
            let text = await sftp.readFilePreview(host: host, jumpHost: jumpHost, path: file.path)
            self.previewContent = text ?? "Unable to read file content or file is binary."
            self.previewFile = file
        }
    }
    
    @ViewBuilder
    private func fileContextMenu(for items: Set<RemoteFileItem.ID>) -> some View {
        if let firstId = items.first, let file = sftp.files.first(where: { $0.id == firstId }) {
            if !file.isDirectory {
                Button("Preview File") { openPreview(file) }
                Button("Download...") { downloadFilePrompt(file) }
            } else {
                Button("Open Folder") {
                    if let host = selectedHost {
                        sftp.listDirectory(host: host, jumpHost: jumpHost, path: file.path)
                    }
                }
                Button("Open in Terminal Tab") {
                    if let host = selectedHost {
                        let jh = jumpHost
                        sessionManager.openHost(host, jumpHost: jh)
                        navManager.navigateToTerminal()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            sessionManager.activeTab?.send(text: "cd '\(file.path)'", appendNewline: true)
                        }
                    }
                }
            }
            Divider()
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(file.path, forType: .string)
            }
            Divider()
            Button(role: .destructive, action: {
                if let host = selectedHost {
                    Task { _ = await sftp.deleteItem(host: host, jumpHost: jumpHost, item: file) }
                }
            }) {
                Text("Delete")
            }
        }
    }
    
    private func uploadFilePrompt() {
        guard let host = selectedHost else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            let folder = sftp.currentPath
            Task {
                _ = await sftp.uploadFile(host: host, jumpHost: jumpHost, localURL: url, remoteFolder: folder)
            }
        }
    }
    
    private func downloadFilePrompt(_ item: RemoteFileItem) {
        guard let host = selectedHost else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = item.name
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                _ = await sftp.downloadFile(host: host, jumpHost: jumpHost, item: item, localURL: url)
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let host = selectedHost else { return false }
        let folder = sftp.currentPath
        let jh = jumpHost
        
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let localURL = url else { return }
                Task { @MainActor in
                    _ = await sftp.uploadFile(host: host, jumpHost: jh, localURL: localURL, remoteFolder: folder)
                }
            }
        }
        return true
    }
}

private struct FilePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let file: RemoteFileItem
    let content: String
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: file.iconName)
                    .foregroundColor(.accentColor)
                Text(file.name)
                    .font(.headline)
                Text("(\(file.formattedSize))")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                Text(content)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
            }
            .background(Color(NSColor.textBackgroundColor))
        }
        .frame(minWidth: 600, minHeight: 450)
    }
}

private struct FileRowCell: View {
    let file: RemoteFileItem
    let onDoubleTap: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: file.iconName)
                .foregroundColor(file.isDirectory ? .accentColor : .secondary)
            Text(file.name)
                .fontWeight(file.isDirectory ? .medium : .regular)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onDoubleTap)
    }
}
