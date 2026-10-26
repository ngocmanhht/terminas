import SwiftUI

public struct WorkspaceSwitcherHeaderView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @State private var showingNewSheet = false
    @State private var showingManageSheet = false
    
    public init() {}
    
    public var body: some View {
        Menu {
            // All Workspaces option
            Button(action: { workspaceStore.activeWorkspaceId = nil }) {
                HStack {
                    Label("All Workspaces", systemImage: "globe")
                    if workspaceStore.activeWorkspaceId == nil {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Divider()
            
            // Individual Workspaces
            ForEach(workspaceStore.workspaces) { ws in
                Button(action: { workspaceStore.activeWorkspaceId = ws.id }) {
                    HStack {
                        Label(ws.name, systemImage: ws.iconName)
                        if ws.isProduction {
                            Text("[PROD]")
                        }
                        if workspaceStore.activeWorkspaceId == ws.id {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            
            Divider()
            
            Button(action: { showingNewSheet = true }) {
                Label("New Workspace...", systemImage: "plus")
            }
            
            Button(action: { showingManageSheet = true }) {
                Label("Manage Workspaces...", systemImage: "slider.horizontal.3")
            }
        } label: {
            HStack(spacing: 8) {
                if let active = workspaceStore.activeWorkspace {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: active.colorHex)?.opacity(0.18) ?? Color.accentColor.opacity(0.18))
                            .frame(width: 24, height: 24)
                        Image(systemName: active.iconName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: active.colorHex) ?? .accentColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(active.name)
                                .font(.system(size: 12, weight: .bold))
                                .lineLimit(1)
                            if active.isProduction {
                                Text("PROD")
                                    .font(.system(size: 8, weight: .heavy))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(Color.red.opacity(0.2)))
                                    .foregroundColor(.red)
                            }
                        }
                        Text("Workspace")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 24, height: 24)
                        Image(systemName: "globe")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("All Workspaces")
                            .font(.system(size: 12, weight: .bold))
                            .lineLimit(1)
                        Text("Combined View")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .sheet(isPresented: $showingNewSheet) {
            WorkspaceEditSheet(workspace: nil) { newWs in
                workspaceStore.add(newWs)
            }
        }
        .sheet(isPresented: $showingManageSheet) {
            WorkspaceManageSheet()
        }
    }
}

public struct WorkspacePickerButton: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @State private var showingNewSheet = false
    @State private var showingManageSheet = false
    
    public init() {}
    
    public var body: some View {
        Menu {
            Button(action: { workspaceStore.activeWorkspaceId = nil }) {
                HStack {
                    Label("All Workspaces", systemImage: "globe")
                    if workspaceStore.activeWorkspaceId == nil {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Divider()
            
            ForEach(workspaceStore.workspaces) { ws in
                Button(action: { workspaceStore.activeWorkspaceId = ws.id }) {
                    HStack {
                        Label(ws.name, systemImage: ws.iconName)
                        if ws.isProduction {
                            Text("[PROD]")
                        }
                        if workspaceStore.activeWorkspaceId == ws.id {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            
            Divider()
            
            Button(action: { showingNewSheet = true }) {
                Label("New Workspace...", systemImage: "plus")
            }
            
            Button(action: { showingManageSheet = true }) {
                Label("Manage Workspaces...", systemImage: "slider.horizontal.3")
            }
        } label: {
            HStack(spacing: 5) {
                if let active = workspaceStore.activeWorkspace {
                    Image(systemName: active.iconName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: active.colorHex) ?? .accentColor)
                    Text(active.name)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    if active.isProduction {
                        Text("PROD")
                            .font(.system(size: 8, weight: .heavy))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.red.opacity(0.2)))
                            .foregroundColor(.red)
                    }
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.accentColor)
                    Text("All Workspaces")
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                }
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .sheet(isPresented: $showingNewSheet) {
            WorkspaceEditSheet(workspace: nil) { newWs in
                workspaceStore.add(newWs)
            }
        }
        .sheet(isPresented: $showingManageSheet) {
            WorkspaceManageSheet()
        }
    }
}

public struct WorkspaceEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    private let initialWorkspace: WorkspaceItem?
    private let onSave: (WorkspaceItem) -> Void
    
    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColor: String
    @State private var isProduction: Bool
    
    private let availableIcons = [
        "briefcase.fill",
        "server.rack",
        "house.fill",
        "cloud.fill",
        "exclamationmark.shield.fill",
        "bolt.shield.fill",
        "cube.box.fill",
        "network"
    ]
    
    private let availableColors = [
        "#0A84FF", // Blue
        "#FF3B30", // Red (Prod)
        "#34C759", // Green
        "#FF9500", // Orange
        "#AF52DE", // Purple
        "#5856D6", // Indigo
        "#64D2FF"  // Cyan
    ]
    
    public init(workspace: WorkspaceItem?, onSave: @escaping (WorkspaceItem) -> Void) {
        self.initialWorkspace = workspace
        self.onSave = onSave
        
        _name = State(initialValue: workspace?.name ?? "")
        _selectedIcon = State(initialValue: workspace?.iconName ?? "briefcase.fill")
        _selectedColor = State(initialValue: workspace?.colorHex ?? "#0A84FF")
        _isProduction = State(initialValue: workspace?.isProduction ?? false)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(initialWorkspace == nil ? "New Workspace" : "Edit Workspace")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            
            Divider()
            
            VStack(spacing: 16) {
                HStack {
                    Text("Name:")
                        .frame(width: 80, alignment: .trailing)
                    TextField("e.g. AWS Production, Client X", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    Text("Icon:")
                        .frame(width: 80, alignment: .trailing)
                    HStack(spacing: 8) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button(action: { selectedIcon = icon }) {
                                Image(systemName: icon)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(selectedIcon == icon ? Color.accentColor.opacity(0.2) : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(selectedIcon == icon ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Spacer()
                }
                
                HStack {
                    Text("Color:")
                        .frame(width: 80, alignment: .trailing)
                    HStack(spacing: 10) {
                        ForEach(availableColors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex) ?? .blue)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColor == hex ? 2 : 0)
                                )
                                .onTapGesture { selectedColor = hex }
                        }
                    }
                    Spacer()
                }
                
                Toggle("Mark as Production Environment", isOn: $isProduction)
                    .padding(.leading, 88)
                
                if isProduction {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Adds a red safety reminder badge on all terminals in this workspace to prevent accidental destructive commands.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(6)
                    .padding(.leading, 88)
                }
            }
            .padding()
        }
        .frame(width: 480, height: 320)
    }
    
    private func save() {
        var ws = initialWorkspace ?? WorkspaceItem(
            name: name,
            iconName: selectedIcon,
            colorHex: selectedColor,
            isProduction: isProduction
        )
        ws.name = name.trimmingCharacters(in: .whitespaces)
        ws.iconName = selectedIcon
        ws.colorHex = selectedColor
        ws.isProduction = isProduction
        onSave(ws)
        dismiss()
    }
}

public struct WorkspaceManageSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @State private var editingWorkspace: WorkspaceItem? = nil
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Manage Workspaces")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
            
            Divider()
            
            List {
                ForEach(workspaceStore.workspaces) { ws in
                    HStack(spacing: 12) {
                        Image(systemName: ws.iconName)
                            .foregroundColor(Color(hex: ws.colorHex) ?? .accentColor)
                            .frame(width: 20)
                        
                        Text(ws.name)
                            .fontWeight(.medium)
                        
                        if ws.isProduction {
                            Text("PROD")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.red.opacity(0.2)))
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        Button("Edit") {
                            editingWorkspace = ws
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button(role: .destructive, action: {
                            workspaceStore.delete(ws)
                        }) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .disabled(workspaceStore.workspaces.count <= 1)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)
        }
        .frame(width: 460, height: 360)
        .sheet(item: $editingWorkspace) { ws in
            WorkspaceEditSheet(workspace: ws) { updated in
                workspaceStore.update(updated)
            }
        }
    }
}
