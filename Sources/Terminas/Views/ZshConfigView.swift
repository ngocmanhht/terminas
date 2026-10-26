import SwiftUI
import AppKit

public enum ZshViewMode: String, CaseIterable, Identifiable {
    case env = "Env"
    case plugins = "Plugins"
    case aliases = "Aliases"
    case path = "PATH"
    case raw = "Raw"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .env: return "curlybraces"
        case .plugins: return "puzzlepiece.extension"
        case .aliases: return "arrow.right.arrow.left"
        case .path: return "signpost.right.and.left"
        case .raw: return "doc.text"
        }
    }
}

public struct ZshConfigView: View {
    @EnvironmentObject private var zshManager: ZshConfigFileManager
    @EnvironmentObject private var sessionManager: TerminalSessionManager
    @EnvironmentObject private var navManager: AppNavigationManager
    
    @State private var selectedMode: ZshViewMode = .env
    @State private var searchText: String = ""
    @State private var editingRawText: String = ""
    @State private var isDirty: Bool = false
    
    @State private var showingAddEnvSheet = false
    @State private var editingEnv: ZshEnvItem? = nil
    
    @State private var showingAddPluginSheet = false
    
    @State private var showingAddAliasSheet = false
    @State private var editingAlias: ZshAliasItem? = nil
    
    @State private var showingAddPathSheet = false
    @State private var copiedItemId: String? = nil
    
    public init() {}
    
    private var filteredEnvs: [ZshEnvItem] {
        if searchText.isEmpty { return zshManager.envVariables }
        return zshManager.envVariables.filter {
            $0.key.localizedCaseInsensitiveContains(searchText) ||
            $0.value.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredAliases: [ZshAliasItem] {
        if searchText.isEmpty { return zshManager.aliases }
        return zshManager.aliases.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.command.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredPlugins: [ZshPluginItem] {
        if searchText.isEmpty { return zshManager.plugins }
        return zshManager.plugins.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                // File selector menu
                Menu {
                    ForEach(ShellFileTarget.allCases) { file in
                        Button(action: {
                            zshManager.selectFile(file)
                            editingRawText = zshManager.rawContent
                            isDirty = false
                        }) {
                            HStack {
                                Text("~/\(file.rawValue)")
                                if zshManager.activeFile == file {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)
                        Text("~/\(zshManager.activeFile.rawValue)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                    .fixedSize(horizontal: true, vertical: false)
                }
                .menuStyle(.borderlessButton)
                .help("Select shell config file to view and edit")
                
                // Mode Picker
                Picker("", selection: $selectedMode) {
                    ForEach(ZshViewMode.allCases) { mode in
                        HStack(spacing: 4) {
                            Image(systemName: mode.iconName)
                            Text(mode.rawValue)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minWidth: 260, idealWidth: 320, maxWidth: 360)
                .fixedSize(horizontal: true, vertical: false)
                
                Spacer()
                
                // Syntax status pill
                if let syntax = zshManager.syntaxCheckResult {
                    HStack(spacing: 4) {
                        Image(systemName: zshManager.isSyntaxValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                        Text(zshManager.isSyntaxValid ? "Syntax OK" : "Syntax Error")
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(zshManager.isSyntaxValid ? .green : .orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill((zshManager.isSyntaxValid ? Color.green : Color.orange).opacity(0.12)))
                    .fixedSize(horizontal: true, vertical: true)
                    .help(syntax)
                }
                
                // Save Button
                Button(action: saveChanges) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save")
                    }
                    .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(selectedMode == .raw ? !isDirty : false)
                .fixedSize(horizontal: true, vertical: false)
                .keyboardShortcut("s", modifiers: .command)
                .help("Save changes (⌘S)")
                
                // More actions menu
                Menu {
                    Button("Test Syntax (zsh -n)") {
                        zshManager.testSyntax()
                    }
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([zshManager.currentFileURL])
                    }
                    Button("Open in Local Shell Tab") {
                        sessionManager.openLocalSession()
                        navManager.navigateToTerminal()
                    }
                    Divider()
                    Button("Reload from Disk") {
                        zshManager.load()
                        editingRawText = zshManager.rawContent
                        isDirty = false
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                }
                .menuStyle(.borderlessButton)
            }
            .detailHeaderPadding(defaultLeading: 0, collapsedLeading: 106)
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 6)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Notification Banners
            if let err = zshManager.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(err)
                        .font(.caption)
                    Spacer()
                    Button(action: { zshManager.errorMessage = nil }) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
            }
            
            // Content according to selected mode
            switch selectedMode {
            case .env:
                envVariablesView
            case .plugins:
                pluginsView
            case .aliases:
                aliasesView
            case .path:
                pathManagerView
            case .raw:
                rawEditorView
            }
        }
        .onAppear {
            editingRawText = zshManager.rawContent
            zshManager.testSyntax()
        }
        .sheet(isPresented: $showingAddEnvSheet) {
            EnvVariableEditSheet(item: nil) { key, value, isExport in
                _ = zshManager.addOrUpdateEnv(key: key, value: value, isExported: isExport)
                editingRawText = zshManager.rawContent
            }
        }
        .sheet(item: $editingEnv) { env in
            EnvVariableEditSheet(item: env) { key, value, isExport in
                _ = zshManager.addOrUpdateEnv(key: key, value: value, isExported: isExport)
                editingRawText = zshManager.rawContent
            }
        }
        .sheet(isPresented: $showingAddAliasSheet) {
            AliasEditSheet(item: nil) { name, command in
                _ = zshManager.addOrUpdateAlias(name: name, command: command)
                editingRawText = zshManager.rawContent
            }
        }
        .sheet(item: $editingAlias) { alias in
            AliasEditSheet(item: alias) { name, command in
                _ = zshManager.addOrUpdateAlias(name: name, command: command)
                editingRawText = zshManager.rawContent
            }
        }
        .sheet(isPresented: $showingAddPluginSheet) {
            AddPluginSheet { newPlugin in
                _ = zshManager.addPlugin(name: newPlugin)
                editingRawText = zshManager.rawContent
            }
        }
        .sheet(isPresented: $showingAddPathSheet) {
            AddPathEntrySheet { newDir in
                _ = zshManager.addPathEntry(directory: newDir)
                editingRawText = zshManager.rawContent
            }
        }
    }
    
    private func saveChanges() {
        if selectedMode == .raw {
            _ = zshManager.saveRaw(editingRawText)
            isDirty = false
        } else {
            _ = zshManager.saveRaw(zshManager.rawContent)
        }
    }
    
    // MARK: - Tab 1: Environment Variables
    private var envVariablesView: some View {
        VStack(spacing: 0) {
            // Search & Action row
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search environment variables...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.05)))
                
                Button(action: { showingAddEnvSheet = true }) {
                    Label("Add Variable", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            
            Divider()
            
            if filteredEnvs.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "curlybraces")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(zshManager.envVariables.isEmpty ? "No Environment Variables Found" : "No Variables Matching Search")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Add variables like JAVA_HOME, GOPATH, NODE_ENV, or API tokens.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: { showingAddEnvSheet = true }) {
                        Label("Add First Environment Variable", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredEnvs) { env in
                        HStack(alignment: .center, spacing: 12) {
                            // Export badge
                            if env.isExported {
                                Text("export")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                                    .foregroundColor(.accentColor)
                            }
                            
                            // Key
                            Text(env.key)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                            
                            Text("=")
                                .foregroundColor(.secondary)
                            
                            // Value
                            Text(env.value)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            // 1-Click Copy
                            Button(action: { copyToClipboard(env.value, id: env.id) }) {
                                Image(systemName: copiedItemId == env.id ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 11))
                                    .foregroundColor(copiedItemId == env.id ? .green : .secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Copy value to clipboard")
                            
                            // Edit
                            Button(action: { editingEnv = env }) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Edit variable")
                            
                            // Delete
                            Button(action: { _ = zshManager.deleteEnv(key: env.key) }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .help("Delete variable")
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
    
    // MARK: - Tab: Plugins
    private var pluginsView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search installed plugins...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.05)))
                
                Button(action: { showingAddPluginSheet = true }) {
                    Label("Add Plugin", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            
            Divider()
            
            if filteredPlugins.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(zshManager.plugins.isEmpty ? "No Oh My Zsh Plugins Configured" : "No Plugins Matching Search")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Add plugins like git, zsh-autosuggestions, or zsh-syntax-highlighting.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: { showingAddPluginSheet = true }) {
                        Label("Add First Plugin", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredPlugins) { plugin in
                        HStack(alignment: .center, spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.accentColor.opacity(0.12))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "puzzlepiece.extension.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.accentColor)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plugin.name)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                Text(pluginDescription(for: plugin.name))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: { copyToClipboard(plugin.name, id: plugin.id) }) {
                                Image(systemName: copiedItemId == plugin.id ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 11))
                                    .foregroundColor(copiedItemId == plugin.id ? .green : .secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Copy plugin name")
                            
                            Button(action: {
                                _ = zshManager.removePlugin(name: plugin.name)
                                editingRawText = zshManager.rawContent
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .help("Remove plugin from plugins=(...)")
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
    
    private func pluginDescription(for name: String) -> String {
        switch name {
        case "git": return "Git aliases and prompt functions"
        case "zsh-autosuggestions": return "Fish-like autosuggestions as you type"
        case "zsh-syntax-highlighting": return "Fish shell-like syntax highlighting for commands"
        case "zsh-completions": return "Additional completion definitions for Zsh"
        case "zsh-history-substring-search": return "Search through history using Up and Down arrows"
        case "docker": return "Autocomplete and aliases for Docker CLI"
        case "brew": return "Homebrew completions and aliases"
        case "node": return "Node.js environment completions"
        case "npm": return "npm completions and shortcuts"
        case "kubectl": return "Kubernetes CLI autocomplete and helper aliases"
        case "autojump": return "Fast directory navigation with j command"
        default: return "Zsh / Oh My Zsh plugin"
        }
    }
    
    // MARK: - Tab 2: Aliases
    private var aliasesView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search aliases...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.05)))
                
                Button(action: { showingAddAliasSheet = true }) {
                    Label("Add Alias", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            
            Divider()
            
            if filteredAliases.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "arrow.right.arrow.left")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(zshManager.aliases.isEmpty ? "No Aliases Found" : "No Aliases Matching Search")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Add command shortcuts like 'll' for 'ls -lah' or 'gst' for 'git status'.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: { showingAddAliasSheet = true }) {
                        Label("Add First Alias", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredAliases) { alias in
                        HStack(alignment: .center, spacing: 12) {
                            Text("alias")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.purple.opacity(0.15)))
                                .foregroundColor(.purple)
                            
                            Text(alias.name)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                            
                            Text("→")
                                .foregroundColor(.secondary.opacity(0.6))
                            
                            Text(alias.command)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Button(action: { copyToClipboard(alias.command, id: alias.id) }) {
                                Image(systemName: copiedItemId == alias.id ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 11))
                                    .foregroundColor(copiedItemId == alias.id ? .green : .secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Copy command")
                            
                            Button(action: { editingAlias = alias }) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: { _ = zshManager.deleteAlias(name: alias.name) }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
    
    // MARK: - Tab 3: PATH Manager
    private var pathManagerView: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("System & Shell $PATH Directories")
                        .font(.headline)
                    Text("Binaries in these directories can be run directly from terminal without full path.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { showingAddPathSheet = true }) {
                    Label("Add to PATH", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            
            Divider()
            
            List {
                ForEach(zshManager.pathEntries) { item in
                    HStack(spacing: 10) {
                        Image(systemName: item.existsOnDisk ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(item.existsOnDisk ? .green : .orange)
                            .font(.system(size: 12))
                        
                        Text(item.directory)
                            .font(.system(size: 12, design: .monospaced))
                        
                        Spacer()
                        
                        if !item.existsOnDisk {
                            Text("Directory Missing")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.orange.opacity(0.12)))
                        }
                        
                        Button(action: { copyToClipboard(item.directory, id: item.id) }) {
                            Image(systemName: copiedItemId == item.id ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11))
                                .foregroundColor(copiedItemId == item.id ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Copy directory path")
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)
        }
    }
    
    // MARK: - Tab 4: Raw Editor
    private var rawEditorView: some View {
        VStack(spacing: 0) {
            TextEditor(text: $editingRawText)
                .font(.system(size: 12, design: .monospaced))
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .onChange(of: editingRawText) { _, newValue in
                    isDirty = (newValue != zshManager.rawContent)
                }
            
            Divider()
            
            // Footer status bar
            HStack(spacing: 12) {
                Text("\(editingRawText.components(separatedBy: "\n").count) lines")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("•")
                    .foregroundColor(.secondary.opacity(0.4))
                
                Text("\(editingRawText.count) characters")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if isDirty {
                    Text("•")
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Unsaved Changes (Press ⌘S)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                Button("Discard Changes") {
                    editingRawText = zshManager.rawContent
                    isDirty = false
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
                .disabled(!isDirty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
    
    private func copyToClipboard(_ text: String, id: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedItemId = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedItemId == id { copiedItemId = nil }
        }
    }
}

// MARK: - Add / Edit Env Variable Sheet
private struct EnvVariableEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: ZshEnvItem?
    let onSave: (String, String, Bool) -> Void
    
    @State private var key: String = ""
    @State private var value: String = ""
    @State private var isExported: Bool = true
    
    init(item: ZshEnvItem?, onSave: @escaping (String, String, Bool) -> Void) {
        self.item = item
        self.onSave = onSave
        _key = State(initialValue: item?.key ?? "")
        _value = State(initialValue: item?.value ?? "")
        _isExported = State(initialValue: item?.isExported ?? true)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text(item == nil ? "Add Environment Variable" : "Edit Environment Variable")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Variable Name (e.g. JAVA_HOME, OPENAI_API_KEY)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("VARIABLE_NAME", text: $key)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Variable Value")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Value or path", text: $value)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
            }
            
            Toggle("Export variable for child processes (export KEY=VALUE)", isOn: $isExported)
                .font(.subheadline)
            
            Divider()
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(item == nil ? "Add Variable" : "Save Changes") {
                    onSave(key, value, isExported)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 440)
    }
}

// MARK: - Add / Edit Alias Sheet
private struct AliasEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: ZshAliasItem?
    let onSave: (String, String) -> Void
    
    @State private var name: String = ""
    @State private var command: String = ""
    
    init(item: ZshAliasItem?, onSave: @escaping (String, String) -> Void) {
        self.item = item
        self.onSave = onSave
        _name = State(initialValue: item?.name ?? "")
        _command = State(initialValue: item?.command ?? "")
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text(item == nil ? "Add Shell Alias" : "Edit Shell Alias")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Shortcut Name (e.g. ll, gst, dcup)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("alias_name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Command to Execute (e.g. ls -la, git status, docker compose up -d)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("command", text: $command)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
            }
            
            Divider()
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(item == nil ? "Add Alias" : "Save Changes") {
                    onSave(name, command)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || command.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 440)
    }
}

// MARK: - Add PATH Entry Sheet
private struct AddPathEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (String) -> Void
    @State private var pathDirectory: String = ""
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Add Directory to $PATH")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Directory Path")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    TextField("/opt/homebrew/bin or ~/bin", text: $pathDirectory)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                    
                    Button("Browse...") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url {
                            pathDirectory = url.path
                        }
                    }
                }
            }
            
            Divider()
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add to PATH") {
                    onAdd(pathDirectory)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(pathDirectory.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 440)
    }
}

// MARK: - Add Plugin Sheet
private struct AddPluginSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (String) -> Void
    
    @State private var pluginName: String = ""
    
    private let popularPlugins = [
        "git",
        "zsh-autosuggestions",
        "zsh-syntax-highlighting",
        "zsh-completions",
        "zsh-history-substring-search",
        "docker",
        "brew",
        "node",
        "npm",
        "kubectl",
        "autojump",
        "macos"
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Add Oh My Zsh Plugin")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Plugin Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("e.g. zsh-autosuggestions, git, docker", text: $pluginName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Popular Recommendations:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 135))], spacing: 6) {
                    ForEach(popularPlugins, id: \.self) { plug in
                        Button(action: {
                            pluginName = plug
                        }) {
                            Text(plug)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Divider()
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add to plugins=(...)") {
                    onAdd(pluginName)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(pluginName.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 480)
    }
}
