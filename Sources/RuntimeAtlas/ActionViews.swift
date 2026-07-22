import RuntimeAtlasCore
import SwiftUI

struct WorktreeCommandsSection: View {
    @EnvironmentObject private var model: AtlasAppModel
    @EnvironmentObject private var runner: ActionRunner
    @Environment(\.atlasCopy) private var copy
    let repository: RepositoryStatus
    let worktree: WorktreeStatus
    @State private var actionToPrepare: CustomActionDefinition?
    @State private var actionShowingOutput: CustomActionDefinition?

    private var actions: [CustomActionDefinition] { model.actions(for: repository.id) }
    private var availableWorktrees: [WorktreeStatus] {
        repository.worktrees.filter { $0.availability == .available }
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150, maximum: 260), spacing: 8, alignment: .leading)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(actions) { action in compactAction(action) }
        }
        .sheet(item: $actionToPrepare) { action in
            ActionExecutionView(action: action, repository: repository, worktree: worktree)
                .environmentObject(model).environmentObject(runner)
                .environment(\.atlasCopy, copy)
        }
        .sheet(item: $actionShowingOutput) { action in
            if let state = runner.state(for: action, worktreePath: worktree.path) {
                ActionOutputView(action: action, state: state)
                    .environment(\.atlasCopy, copy)
            }
        }
    }

    @ViewBuilder private func compactAction(_ action: CustomActionDefinition) -> some View {
        let state = runner.state(for: action, worktreePath: worktree.path)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Button {
                    if runner.isRunning(action, worktreePath: worktree.path) {
                        runner.stop(action: action, worktreePath: worktree.path)
                    } else {
                        prepare(action)
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: action.kind == .session ? "play.fill" : "terminal.fill")
                        Text(action.name)
                            .lineLimit(1)
                        Spacer(minLength: 3)
                        if runner.isRunning(action, worktreePath: worktree.path) {
                            Text(copy.stop)
                                .font(.system(size: RuntimeAtlasTheme.Typography.caption, weight: .semibold))
                                .foregroundStyle(RuntimeAtlasTheme.amber)
                        }
                    }
                }
                .buttonStyle(CompactCommandButtonStyle(running: runner.isRunning(action, worktreePath: worktree.path)))
                .disabled(worktree.availability != .available)
                .accessibilityLabel(commandAccessibilityLabel(action))

                if let state, !state.output.isEmpty {
                    Button {
                        actionShowingOutput = action
                    } label: {
                        Image(systemName: "doc.text")
                            .font(.system(size: RuntimeAtlasTheme.Typography.secondary, weight: .medium))
                            .frame(width: 28, height: 28)
                            .background(RoundedRectangle(cornerRadius: 5).fill(RuntimeAtlasTheme.control))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                    .help(copy.output)
                    .accessibilityLabel("\(action.name), \(copy.output)")
                }
            }

            if let failure = failureText(state?.phase) {
                Text(failure)
                    .font(.system(size: RuntimeAtlasTheme.Typography.caption, weight: .medium))
                    .foregroundStyle(RuntimeAtlasTheme.red)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func commandAccessibilityLabel(_ action: CustomActionDefinition) -> String {
        if runner.isRunning(action, worktreePath: worktree.path) {
            return "\(action.name), \(copy.running), \(copy.stop)"
        }
        return "\(action.name), \(action.kind == .session ? copy.start : copy.run)"
    }

    private func prepare(_ action: CustomActionDefinition) {
        guard worktree.availability == .available else { return }
        if action.inputs.isEmpty && action.risk == .normal {
            do {
                let plan = try CustomActionPlanner.plan(action: action, values: [:], selectedWorktree: worktree.path, repositoryRoot: repository.path, availableWorktrees: availableWorktrees.map(\.path))
                try runner.start(action: action, plan: plan, worktreePath: worktree.path)
            } catch let error as CustomActionError { model.operationMessage = copy.customActionError(error) }
            catch { model.operationMessage = copy.actionLaunchFailed }
        } else { actionToPrepare = action }
    }

    private func failureText(_ phase: ActionRunPhase?) -> String? {
        if case .failed(let code) = phase { return copy.failedExit(code) }
        return nil
    }
}

private struct CompactCommandButtonStyle: ButtonStyle {
    let running: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: RuntimeAtlasTheme.Typography.secondary, weight: .semibold))
            .foregroundStyle(RuntimeAtlasTheme.primaryText)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 32)
            .background {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(RuntimeAtlasTheme.control.opacity(configuration.isPressed ? 0.72 : 1))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(running ? RuntimeAtlasTheme.amber.opacity(0.45) : RuntimeAtlasTheme.border)
            }
    }
}

private struct ActionOutputView: View {
    @Environment(\.atlasCopy) private var copy
    @Environment(\.dismiss) private var dismiss
    let action: CustomActionDefinition
    let state: ActionRunState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(action.name)
                    .font(.system(size: RuntimeAtlasTheme.Typography.modalTitle, weight: .semibold))
                Spacer()
                Button(copy.close) { dismiss() }
            }
            Text(state.displayCommand)
                .font(.system(size: RuntimeAtlasTheme.Typography.technical, design: .monospaced))
                .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                .textSelection(.enabled)
            ScrollView([.horizontal, .vertical]) {
                Text(state.output)
                    .font(.system(size: RuntimeAtlasTheme.Typography.technical, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 6).fill(RuntimeAtlasTheme.control))
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 300)
        .background(RuntimeAtlasTheme.background)
    }
}

struct ActionManagerView: View {
    @EnvironmentObject private var model: AtlasAppModel
    @EnvironmentObject private var runner: ActionRunner
    @Environment(\.atlasCopy) private var copy
    @Environment(\.dismiss) private var dismiss
    let repository: RepositoryStatus
    @State private var editing: CustomActionDefinition?

    var body: some View {
        VStack(spacing: 0) {
            HStack { Text(copy.repositoryActionsFor(repository.name)).font(.system(size: RuntimeAtlasTheme.Typography.modalTitle, weight: .semibold)); Spacer(); Button(copy.close) { dismiss() } }
                .padding(20)
            Divider()
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(model.actions(for: repository.id)) { action in
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 10) {
                                actionDescription(action)
                                Spacer(minLength: 8)
                                managerButtons(action)
                            }
                            VStack(alignment: .leading, spacing: 9) {
                                actionDescription(action)
                                HStack { Spacer(); managerButtons(action) }
                            }
                        }.padding(12).background(RoundedRectangle(cornerRadius: 6).fill(RuntimeAtlasTheme.control))
                    }
                    Button { editing = CustomActionDefinition(repositoryID: repository.id, name: "", commandTemplate: "") } label: { Label(copy.addAction, systemImage: "plus") }
                        .buttonStyle(AtlasButtonStyle(prominent: true)).frame(maxWidth: .infinity, alignment: .leading)
                }.padding(20)
            }
        }
        .frame(minWidth: 520, minHeight: 480)
        .background(RuntimeAtlasTheme.background)
        .sheet(item: $editing) { action in
            ActionEditorView(action: action) { saved in if model.saveCustomAction(saved) { editing = nil } }
                .environment(\.atlasCopy, copy)
        }
    }

    private func isRunning(_ action: CustomActionDefinition) -> Bool {
        repository.worktrees.contains { runner.isRunning(action, worktreePath: $0.path) }
    }

    private func actionDescription(_ action: CustomActionDefinition) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(action.name).font(.system(size: RuntimeAtlasTheme.Typography.body, weight: .semibold))
            Text(action.commandTemplate).font(.system(size: RuntimeAtlasTheme.Typography.technical, design: .monospaced)).foregroundStyle(RuntimeAtlasTheme.secondaryText).lineLimit(3)
        }
    }

    @ViewBuilder private func managerButtons(_ action: CustomActionDefinition) -> some View {
        Button(copy.editAction) { editing = action }.disabled(isRunning(action))
        Button(role: .destructive) { model.removeCustomAction(action) } label: { Image(systemName: "trash") }
            .help(copy.deleteAction).disabled(isRunning(action))
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
                            ViewThatFits(in: .horizontal) {
                                HStack { inputFields(input: $input); removeInputButton(input.id) }
                                VStack(alignment: .trailing, spacing: 8) { inputFields(input: $input); removeInputButton(input.id) }
                            }
                            Picker("", selection: $input.kind) { Text(copy.textInput).tag(CustomActionInputKind.text); Text(copy.worktreeInput).tag(CustomActionInputKind.worktree); Text(copy.checkboxInput).tag(CustomActionInputKind.flag) }.pickerStyle(.segmented)
                            if input.kind == .flag { TextField("--flag", text: Binding(get: { input.flagArgument ?? "" }, set: { input.flagArgument = $0 })) }
                        }.padding(10).background(RoundedRectangle(cornerRadius: 6).fill(RuntimeAtlasTheme.control))
                    }
                    if let validationMessage { Text(validationMessage).foregroundStyle(RuntimeAtlasTheme.red).font(.system(size: RuntimeAtlasTheme.Typography.secondary)) }
                }.textFieldStyle(.roundedBorder).padding(20)
            }
            Divider()
            HStack { Spacer(); Button(copy.save) { save() }.buttonStyle(AtlasButtonStyle(prominent: true)) }.padding(16)
        }.frame(minWidth: 520, minHeight: 600).background(RuntimeAtlasTheme.background)
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) { Text(title).font(.system(size: RuntimeAtlasTheme.Typography.body, weight: .semibold)); content() }
    }
    @ViewBuilder private func inputFields(input: Binding<CustomActionInputDefinition>) -> some View {
        TextField(copy.inputKey, text: input.key)
        TextField(copy.inputLabel, text: input.label)
    }
    private func removeInputButton(_ id: UUID) -> some View {
        Button(role: .destructive) { draft.inputs.removeAll { $0.id == id } } label: { Image(systemName: "minus.circle") }
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
        }.padding(22).frame(minWidth: 480).background(RuntimeAtlasTheme.background)
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
