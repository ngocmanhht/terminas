import SwiftUI

public struct SnippetEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let initialSnippet: SnippetItem?
    private let onSave: (SnippetItem) -> Void
    
    @State private var title: String
    @State private var command: String
    @State private var category: String
    @State private var runImmediately: Bool
    
    public init(snippet: SnippetItem?, onSave: @escaping (SnippetItem) -> Void) {
        self.initialSnippet = snippet
        self.onSave = onSave
        _title = State(initialValue: snippet?.title ?? "")
        _command = State(initialValue: snippet?.command ?? "")
        _category = State(initialValue: snippet?.category ?? "General")
        _runImmediately = State(initialValue: snippet?.runImmediately ?? true)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(initialSnippet == nil ? "New Snippet" : "Edit Snippet")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || command.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            
            Divider()
            
            VStack(spacing: 16) {
                HStack {
                    Text("Title:")
                        .frame(width: 80, alignment: .trailing)
                    TextField("e.g. Restart Docker", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    Text("Category:")
                        .frame(width: 80, alignment: .trailing)
                    TextField("e.g. Docker, Monitoring", text: $category)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack(alignment: .top) {
                    Text("Command:")
                        .frame(width: 80, alignment: .trailing)
                    TextEditor(text: $command)
                        .font(.system(size: 13, design: .monospaced))
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
                
                Toggle("Execute immediately with Enter (newline)", isOn: $runImmediately)
                    .padding(.leading, 88)
            }
            .padding()
        }
        .frame(width: 480, height: 280)
    }
    
    private func save() {
        var snippet = initialSnippet ?? SnippetItem(
            title: title,
            command: command,
            category: category,
            runImmediately: runImmediately
        )
        snippet.title = title.trimmingCharacters(in: .whitespaces)
        snippet.command = command.trimmingCharacters(in: .whitespacesAndNewlines)
        snippet.category = category.trimmingCharacters(in: .whitespaces)
        snippet.runImmediately = runImmediately
        onSave(snippet)
        dismiss()
    }
}

public struct SnippetsView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var snippetStore: SnippetStore
    @EnvironmentObject private var sessionManager: TerminalSessionManager
    @EnvironmentObject private var navManager: AppNavigationManager
    
    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var editingSnippet: SnippetItem? = nil
    
    public init() {}
    
    private var filteredSnippets: [SnippetItem] {
        let currentWsId = workspaceStore.activeWorkspaceId
        return snippetStore.snippets.filter { snippet in
            let matchesWs = currentWsId == nil || snippet.workspaceId == nil || snippet.workspaceId == currentWsId
            let matchesSearch = searchText.isEmpty ||
                snippet.title.localizedCaseInsensitiveContains(searchText) ||
                snippet.command.localizedCaseInsensitiveContains(searchText) ||
                snippet.category.localizedCaseInsensitiveContains(searchText)
            return matchesWs && matchesSearch
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search & Action Bar
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search snippets...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.05)))
                
                Button(action: { showingAddSheet = true }) {
                    Label("Add Snippet", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .detailHeaderPadding(defaultLeading: 0, collapsedLeading: 108)
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 6)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            if filteredSnippets.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "applescript")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("No Snippets Found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Button(action: { showingAddSheet = true }) {
                        Label("Add Snippet", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
            } else {
                List {
                    ForEach(filteredSnippets) { snippet in
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(snippet.title)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(snippet.category)
                                        .font(.system(size: 10, weight: .medium))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                                        .foregroundColor(.accentColor)
                                }
                                
                                Text(snippet.command)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            if sessionManager.activeTab != nil {
                                Button(action: { sessionManager.sendSnippet(snippet) }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "play.fill")
                                        Text("Run")
                                    }
                                    .font(.system(size: 11, weight: .medium))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(snippet.command, forType: .string)
                            }) {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                            .help("Copy command")
                        }
                        .padding(.vertical, 4)
                        .contextMenu {
                            if sessionManager.activeTab != nil {
                                Button(action: { sessionManager.sendSnippet(snippet) }) {
                                    Label("Run in Active Terminal", systemImage: "play.fill")
                                }
                            }
                            Button(action: { editingSnippet = snippet }) {
                                Label("Edit Snippet", systemImage: "pencil")
                            }
                            Button(role: .destructive, action: { snippetStore.delete(snippet) }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            SnippetEditSheet(snippet: nil) { newSnippet in
                var s = newSnippet
                s.workspaceId = workspaceStore.activeWorkspaceId
                snippetStore.add(s)
            }
        }
        .sheet(item: $editingSnippet) { snip in
            SnippetEditSheet(snippet: snip) { updated in
                snippetStore.update(updated)
            }
        }
    }
}
