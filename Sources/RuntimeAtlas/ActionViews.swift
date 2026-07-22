import RuntimeAtlasCore
import SwiftUI

struct CustomActionsSection: View {
    @EnvironmentObject private var model: AtlasAppModel
    @EnvironmentObject private var runner: ActionRunner
    @Environment(\.atlasCopy) private var copy
    let repository: RepositoryStatus
    let worktree: WorktreeStatus
    @State private var showingManager = false
    @State private var actionToPrepare: CustomActionDefinition?

    private var actions: [CustomActionDefinition] { model.actions(for: repository.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                if actions.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(copy.noActions).font(.system(size: RuntimeAtlasTheme.Typography.body, weight: .semibold))
                        Text(copy.noActionsHelp).font(.system(size: RuntimeAtlasTheme.Typography.secondary)).foregroundStyle(RuntimeAtlasTheme.secondaryText)
                    }
                } else {
                    Text(copy.sessionCloseNotice)
                        .font(.system(size: RuntimeAtlasTheme.Typography.secondary))
                        .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                }
                Spacer()
                Button(copy.configureActions) { showingManager = true }
                    .buttonStyle(AtlasButtonStyle())
            }

            ForEach(actions) { action in actionRow(action) }
        }
        .sheet(isPresented: $showingManager) {
            ActionManagerView(repository: repository)
                .environmentObject(model).environmentObject(runner)
                .environment(\.atlasCopy, copy)
        }
        .sheet(item: $actionToPrepare) { action in
            ActionExecutionView(action: action, repository: repository, worktree: worktree)
                .environmentObject(model).environmentObject(runner)
                .environment(\.atlasCopy, copy)
        }
    }

    @ViewBuilder private func actionRow(_ action: CustomActionDefinition) -> some View {
        let state = runner.state(for: action, worktreePath: worktree.path)
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: action.kind == .session ? "play.rectangle.fill" : "terminal.fill")
                    .foregroundStyle(RuntimeAtlasTheme.accent).font(.system(size: 18))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(action.name).font(.system(size: RuntimeAtlasTheme.Typography.body, weight: .semibold))
                        if action.risk == .destructive {
                            AtlasBadge(text: copy.destructiveAction, icon: "exclamationmark.triangle.fill", color: RuntimeAtlasTheme.amber)
                        }
                    }
                    Text(action.commandTemplate)
                        .font(.system(size: RuntimeAtlasTheme.Typography.technical, design: .monospaced))
                        .foregroundStyle(RuntimeAtlasTheme.secondaryText).lineLimit(2)
                }
                Spacer()
                Text(phaseText(state?.phase))
                    .font(.system(size: RuntimeAtlasTheme.Typography.caption, weight: .medium))
                    .foregroundStyle(phaseColor(state?.phase))
                if runner.isRunning(action, worktreePath: worktree.path) {
                    Button(copy.stop) { runner.stop(action: action, worktreePath: worktree.path) }
                        .buttonStyle(AtlasButtonStyle())
                } else {
                    Button(action.kind == .session ? copy.start : copy.run) { prepare(action) }
                        .buttonStyle(AtlasButtonStyle(prominent: true))
                }
            }
            if let state, !state.output.isEmpty {
                DisclosureGroup(copy.output) {
                    ScrollView(.horizontal) {
                        Text(state.output).font(.system(size: RuntimeAtlasTheme.Typography.technical, design: .monospaced))
                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(maxHeight: 180)
                }.font(.system(size: RuntimeAtlasTheme.Typography.secondary))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 6).fill(RuntimeAtlasTheme.control).overlay { RoundedRectangle(cornerRadius: 6).stroke(RuntimeAtlasTheme.border) })
        .accessibilityElement(children: .contain)
    }

    private func prepare(_ action: CustomActionDefinition) {
        if action.inputs.isEmpty && action.risk == .normal {
            do {
                let plan = try CustomActionPlanner.plan(action: action, values: [:], selectedWorktree: worktree.path, repositoryRoot: repository.path, availableWorktrees: repository.worktrees.map(\.path))
                try runner.start(action: action, plan: plan, worktreePath: worktree.path)
            } catch let error as CustomActionError { model.operationMessage = copy.customActionError(error) }
            catch { model.operationMessage = copy.actionLaunchFailed }
        } else { actionToPrepare = action }
    }

    private func phaseText(_ phase: ActionRunPhase?) -> String {
        switch phase { case .running: copy.running; case .stopping: copy.stopping; case .succeeded: copy.succeeded; case .stopped: copy.stopped; case .failed(let code): copy.failedExit(code); case nil: "" }
    }
    private func phaseColor(_ phase: ActionRunPhase?) -> Color {
        switch phase { case .running: RuntimeAtlasTheme.accent; case .stopping: RuntimeAtlasTheme.amber; case .succeeded, .stopped: RuntimeAtlasTheme.mint; case .failed: RuntimeAtlasTheme.red; case nil: RuntimeAtlasTheme.secondaryText }
    }
}

private struct ActionManagerView: View {
    @EnvironmentObject private var model: AtlasAppModel
    @EnvironmentObject private var runner: ActionRunner
    @Environment(\.atlasCopy) private var copy
    @Environment(\.dismiss) private var dismiss
    let repository: RepositoryStatus
    @State private var editing: CustomActionDefinition?

    var body: some View {
        VStack(spacing: 0) {
            HStack { Text(copy.configureActions).font(.system(size: RuntimeAtlasTheme.Typography.modalTitle, weight: .semibold)); Spacer(); Button(copy.close) { dismiss() } }
                .padding(20)
            Divider()
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(model.actions(for: repository.id)) { action in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(action.name).font(.system(size: RuntimeAtlasTheme.Typography.body, weight: .semibold))
                                Text(action.commandTemplate).font(.system(size: RuntimeAtlasTheme.Typography.technical, design: .monospaced)).foregroundStyle(RuntimeAtlasTheme.secondaryText)
                            }
                            Spacer()
                            Button(copy.editAction) { editing = action }.disabled(isRunning(action))
                            Button(role: .destructive) { model.removeCustomAction(action) } label: { Image(systemName: "trash") }
                                .help(copy.deleteAction).disabled(isRunning(action))
                        }.padding(12).background(RoundedRectangle(cornerRadius: 6).fill(RuntimeAtlasTheme.control))
                    }
                    Button { editing = CustomActionDefinition(repositoryID: repository.id, name: "", commandTemplate: "") } label: { Label(copy.addAction, systemImage: "plus") }
                        .buttonStyle(AtlasButtonStyle(prominent: true)).frame(maxWidth: .infinity, alignment: .leading)
                }.padding(20)
            }
        }
        .frame(minWidth: 680, minHeight: 520)
        .background(RuntimeAtlasTheme.background)
        .sheet(item: $editing) { action in
            ActionEditorView(action: action) { saved in if model.saveCustomAction(saved) { editing = nil } }
                .environment(\.atlasCopy, copy)
        }
    }

    private func isRunning(_ action: CustomActionDefinition) -> Bool {
        repository.worktrees.contains { runner.isRunning(action, worktreePath: $0.path) }
    }
}

private struct ActionEditorView: View {
    @Environment(\.atlasCopy) private var copy
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CustomActionDefinition
    @State private var effectsText: String
    @State private var validationMessage: String?
    let onSave: (CustomActionDefinition) -> Void

    init(action: CustomActionDefinition, onSave: @escaping (CustomActionDefinition) -> Void) {
        _draft = State(initialValue: action); _effectsText = State(initialValue: action.effects.joined(separator: "\n")); self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack { Text(draft.name.isEmpty ? copy.addAction : copy.editAction).font(.system(size: RuntimeAtlasTheme.Typography.modalTitle, weight: .semibold)); Spacer(); Button(copy.cancel) { dismiss() } }
                .padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    labeled(copy.actionName) { TextField(copy.actionName, text: $draft.name) }
                    labeled(copy.commandTemplate) {
                        TextField("npm run dev", text: $draft.commandTemplate).font(.system(size: RuntimeAtlasTheme.Typography.technical, design: .monospaced))
                        Text(copy.commandPlaceholderHelp).font(.system(size: RuntimeAtlasTheme.Typography.caption)).foregroundStyle(RuntimeAtlasTheme.secondaryText)
                    }
                    Picker(copy.actionKind, selection: $draft.kind) { Text(copy.oneTimeTask).tag(CustomActionKind.task); Text(copy.runningSession).tag(CustomActionKind.session) }.pickerStyle(.segmented)
                    Picker(copy.runFrom, selection: $draft.workingDirectory) { Text(copy.selectedWorktreeLocation).tag(CustomActionWorkingDirectory.selectedWorktree); Text(copy.repositoryRootLocation).tag(CustomActionWorkingDirectory.repositoryRoot) }
                    Toggle(copy.destructiveAction, isOn: Binding(get: { draft.risk == .destructive }, set: { draft.risk = $0 ? .destructive : .normal }))
                    labeled(copy.effects) { TextEditor(text: $effectsText).frame(minHeight: 70).font(.system(size: RuntimeAtlasTheme.Typography.body)) }
                    HStack { Text(copy.inputs).font(.system(size: RuntimeAtlasTheme.Typography.sectionTitle, weight: .semibold)); Spacer(); Button(copy.addInput) { draft.inputs.append(CustomActionInputDefinition(key: "input\(draft.inputs.count + 1)", label: "", kind: .text)) } }
                    ForEach($draft.inputs) { $input in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { TextField(copy.inputKey, text: $input.key); TextField(copy.inputLabel, text: $input.label); Button(role: .destructive) { draft.inputs.removeAll { $0.id == input.id } } label: { Image(systemName: "minus.circle") } }
                            Picker("", selection: $input.kind) { Text(copy.textInput).tag(CustomActionInputKind.text); Text(copy.worktreeInput).tag(CustomActionInputKind.worktree); Text(copy.checkboxInput).tag(CustomActionInputKind.flag) }.pickerStyle(.segmented)
                            if input.kind == .flag { TextField("--flag", text: Binding(get: { input.flagArgument ?? "" }, set: { input.flagArgument = $0 })) }
                        }.padding(10).background(RoundedRectangle(cornerRadius: 6).fill(RuntimeAtlasTheme.control))
                    }
                    if let validationMessage { Text(validationMessage).foregroundStyle(RuntimeAtlasTheme.red).font(.system(size: RuntimeAtlasTheme.Typography.secondary)) }
                }.textFieldStyle(.roundedBorder).padding(20)
            }
            Divider()
            HStack { Spacer(); Button(copy.save) { save() }.buttonStyle(AtlasButtonStyle(prominent: true)) }.padding(16)
        }.frame(minWidth: 700, minHeight: 680).background(RuntimeAtlasTheme.background)
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) { Text(title).font(.system(size: RuntimeAtlasTheme.Typography.body, weight: .semibold)); content() }
    }
    private func save() {
        draft.effects = effectsText.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        do { try CustomActionPlanner.validate(draft); onSave(draft) }
        catch let error as CustomActionError { validationMessage = copy.customActionError(error) }
        catch { validationMessage = copy.actionSaveFailed }
    }
}

private struct ActionExecutionView: View {
    @EnvironmentObject private var model: AtlasAppModel
    @EnvironmentObject private var runner: ActionRunner
    @Environment(\.atlasCopy) private var copy
    @Environment(\.dismiss) private var dismiss
    let action: CustomActionDefinition
    let repository: RepositoryStatus
    let worktree: WorktreeStatus
    @State private var values: [String: String]

    init(action: CustomActionDefinition, repository: RepositoryStatus, worktree: WorktreeStatus) {
        self.action = action; self.repository = repository; self.worktree = worktree
        _values = State(initialValue: Dictionary(uniqueKeysWithValues: action.inputs.map { ($0.key, $0.kind == .worktree ? worktree.path : ($0.kind == .flag ? "false" : "")) }))
    }

    private var plan: Result<CustomActionPlan, Error> {
        Result { try CustomActionPlanner.plan(action: action, values: values, selectedWorktree: worktree.path, repositoryRoot: repository.path, availableWorktrees: repository.worktrees.filter { $0.availability == .available }.map(\.path)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text(copy.confirmAction).font(.system(size: RuntimeAtlasTheme.Typography.modalTitle, weight: .semibold)); Spacer(); Button(copy.cancel) { dismiss() } }
            if action.risk == .destructive { InlineNotice(icon: "exclamationmark.triangle.fill", title: copy.destructiveAction, message: copy.destructiveWarning, color: RuntimeAtlasTheme.amber) }
            ForEach(action.inputs) { input in inputView(input) }
            if !action.effects.isEmpty { VStack(alignment: .leading, spacing: 5) { Text(copy.effects).font(.system(size: RuntimeAtlasTheme.Typography.body, weight: .semibold)); ForEach(action.effects, id: \.self) { Text("• \($0)") } } }
            VStack(alignment: .leading, spacing: 6) {
                Text(copy.exactCommand).font(.system(size: RuntimeAtlasTheme.Typography.body, weight: .semibold))
                switch plan { case .success(let plan): Text(plan.displayCommand).font(.system(size: RuntimeAtlasTheme.Typography.technical, design: .monospaced)).textSelection(.enabled); case .failure(let error): Text(copy.localizedCoreMessage(error.localizedDescription)).foregroundStyle(RuntimeAtlasTheme.red) }
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 6).fill(RuntimeAtlasTheme.control))
            HStack { Spacer(); Button(action.kind == .session ? copy.start : copy.run) { execute() }.buttonStyle(AtlasButtonStyle(prominent: true)).disabled((try? plan.get()) == nil) }
        }.padding(22).frame(minWidth: 620).background(RuntimeAtlasTheme.background)
    }

    @ViewBuilder private func inputView(_ input: CustomActionInputDefinition) -> some View {
        switch input.kind {
        case .text: VStack(alignment: .leading) { Text(input.label); TextField(input.label, text: binding(input.key)).textFieldStyle(.roundedBorder) }
        case .worktree: Picker(input.label, selection: binding(input.key)) { ForEach(repository.worktrees.filter { $0.availability == .available }) { Text(URL(fileURLWithPath: $0.path).lastPathComponent).tag($0.path) } }
        case .flag: Toggle(input.label, isOn: Binding(get: { values[input.key] == "true" }, set: { values[input.key] = $0 ? "true" : "false" }))
        }
    }
    private func binding(_ key: String) -> Binding<String> { Binding(get: { values[key] ?? "" }, set: { values[key] = $0 }) }
    private func execute() {
        guard case .success(let resolved) = plan else { return }
        do { try runner.start(action: action, plan: resolved, worktreePath: worktree.path); dismiss() }
        catch { model.operationMessage = copy.actionLaunchFailed; dismiss() }
    }
}
