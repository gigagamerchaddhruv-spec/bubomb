import SwiftUI
import BubombCore
#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers
#endif

/// Comprehensive editor for configuring Bubomb payloads.
@MainActor
public struct PayloadEditorView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var executor: PayloadExecutor

    @State private var payloadName: String = ""
    @State private var selectedTypeIndex: Int = 0

    // Shell state
    @State private var shellCommand: String = ""
    @State private var shellPath: String = "/bin/zsh"
    @State private var shellWorkDir: String = ""
    @State private var shellArgs: String = ""
    @State private var shellTimeout: TimeInterval = 30
    @State private var envKeyInput: String = ""
    @State private var envValInput: String = ""
    @State private var envVars: [String: String] = [:]

    // App state
    @State private var appPath: String = ""
    @State private var appArgs: String = ""

    // URL state
    @State private var urlString: String = "https://"

    // Script state
    @State private var scriptPath: String = ""
    @State private var scriptArgs: String = ""
    @State private var scriptWorkDir: String = ""
    @State private var scriptTimeout: TimeInterval = 60

    // Sequence state
    @State private var sequenceSteps: [SequenceStep] = []
    @State private var sequenceStopOnError: Bool = true
    @State private var editingStepIndex: Int? = nil
    @State private var showStepEditor: Bool = false
    @State private var tempStep: SequenceStep = SequenceStep(name: "New Step", action: .openURL(urlString: "https://apple.com"))

    // Feedback & Validation
    @State private var feedbackMessage: String? = nil
    @State private var isErrorFeedback: Bool = false
    @State private var showDestructiveConfirmation: Bool = false
    @State private var pendingDestructiveActionReason: String? = nil

    public init(settingsStore: SettingsStore = .shared, executor: PayloadExecutor? = nil) {
        self.settingsStore = settingsStore
        self.executor = executor ?? PayloadExecutor.shared
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerStatusSection
                payloadTypeSelector
                configurationFormSection
                safetyNoticeSection
                actionButtonsSection
            }
            .padding(18)
        }
        .background(BubombTheme.windowBackground)
        .onAppear {
            loadFromActivePayload()
        }
        .sheet(isPresented: $showStepEditor) {
            SequenceStepEditorView(
                step: $tempStep,
                onSave: {
                    if let idx = editingStepIndex, idx < sequenceSteps.count {
                        sequenceSteps[idx] = tempStep
                    } else {
                        sequenceSteps.append(tempStep)
                    }
                    showStepEditor = false
                },
                onCancel: {
                    showStepEditor = false
                }
            )
        }
        .alert("⚠️ Confirm Destructive Action", isPresented: $showDestructiveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Detonate Anyway", role: .destructive) {
                executeDetonation(bypassConfirmation: true)
            }
        } message: {
            Text(pendingDestructiveActionReason ?? "This action may perform irreversible changes.")
        }
    }

    // MARK: - Sections

    private var headerStatusSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Configured Payload:")
                        .font(.headline)
                        .foregroundColor(BubombTheme.textPrimary)

                    if let active = settingsStore.settings.activePayload {
                        HStack(spacing: 4) {
                            Circle().fill(BubombTheme.successGreen).frame(width: 8, height: 8)
                            Text(active.name)
                                .font(.subheadline.bold())
                                .foregroundColor(BubombTheme.accentOrange)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Circle().fill(BubombTheme.accentAmber).frame(width: 8, height: 8)
                            Text("Unconfigured")
                                .font(.subheadline)
                                .foregroundColor(BubombTheme.textMuted)
                        }
                    }
                }

                Text("Configure the boom. One click on the menu bar bomb detonates this action instantly.")
                    .font(.caption)
                    .foregroundColor(BubombTheme.textSecondary)
            }

            Spacer()

            AnimatedBombView(size: 44, isDetonating: executor.currentState.isRunning) {
                detonateOrConfirm()
            }
        }
        .bubombCard()
    }

    private var payloadTypeSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Payload Name")
                    .font(.caption.bold())
                    .foregroundColor(BubombTheme.textSecondary)
                Spacer()
            }

            TextField("e.g. Build & Start Servers", text: $payloadName)
                .textFieldStyle(.roundedBorder)

            Text("Payload Type")
                .font(.caption.bold())
                .foregroundColor(BubombTheme.textSecondary)
                .padding(.top, 4)

            Picker("Type", selection: $selectedTypeIndex) {
                Text("Shell Command").tag(0)
                Text("Open Application").tag(1)
                Text("Open URL").tag(2)
                Text("Run Script").tag(3)
                Text("Multi-step Sequence").tag(4)
            }
            .pickerStyle(.segmented)
        }
        .bubombCard()
    }

    @ViewBuilder
    private var configurationFormSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch selectedTypeIndex {
            case 0:
                shellConfigurationForm
            case 1:
                applicationConfigurationForm
            case 2:
                urlConfigurationForm
            case 3:
                scriptConfigurationForm
            case 4:
                sequenceConfigurationForm
            default:
                EmptyView()
            }
        }
        .bubombCard()
    }

    // MARK: - Type Specific Forms

    private var shellConfigurationForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shell Command Configuration")
                .font(.subheadline.bold())
                .foregroundColor(BubombTheme.accentOrange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Command:").font(.caption).foregroundColor(BubombTheme.textSecondary)
                TextEditor(text: $shellCommand)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 70)
                    .padding(4)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(BubombTheme.borderSubtle, lineWidth: 1))
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shell Environment:").font(.caption).foregroundColor(BubombTheme.textSecondary)
                    Picker("", selection: $shellPath) {
                        Text("Zsh (/bin/zsh)").tag("/bin/zsh")
                        Text("Bash (/bin/bash)").tag("/bin/bash")
                        Text("Sh (/bin/sh)").tag("/bin/sh")
                        Text("Direct Executable (no shell)").tag("")
                    }
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Timeout (Seconds):").font(.caption).foregroundColor(BubombTheme.textSecondary)
                    Picker("", selection: $shellTimeout) {
                        Text("5s").tag(TimeInterval(5))
                        Text("10s").tag(TimeInterval(10))
                        Text("30s (Default)").tag(TimeInterval(30))
                        Text("60s").tag(TimeInterval(60))
                        Text("120s").tag(TimeInterval(120))
                        Text("No Timeout").tag(TimeInterval(0))
                    }
                    .labelsHidden()
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Working Directory:").font(.caption).foregroundColor(BubombTheme.textSecondary)
                HStack {
                    TextField("/Users/... (Leave empty for home)", text: $shellWorkDir)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse...") {
                        chooseDirectory(target: $shellWorkDir)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Environment Variables:").font(.caption).foregroundColor(BubombTheme.textSecondary)
                HStack {
                    TextField("KEY", text: $envKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                    TextField("VALUE", text: $envValInput)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        let k = envKeyInput.trimmingCharacters(in: .whitespaces)
                        if !k.isEmpty {
                            envVars[k] = envValInput
                            envKeyInput = ""
                            envValInput = ""
                        }
                    }
                }

                if !envVars.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(envVars.keys.sorted()), id: \.self) { key in
                            HStack {
                                Text("\(key)=\(envVars[key] ?? "")")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(BubombTheme.accentPurple)
                                Spacer()
                                Button(action: { envVars.removeValue(forKey: key) }) {
                                    Image(systemName: "trash").font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(4)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private var applicationConfigurationForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Open Application Configuration")
                .font(.subheadline.bold())
                .foregroundColor(BubombTheme.accentOrange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Target Application:").font(.caption).foregroundColor(BubombTheme.textSecondary)
                HStack {
                    TextField("/Applications/Xcode.app", text: $appPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Choose App...") {
                        chooseApplication()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Optional Launch Arguments (Space separated):").font(.caption).foregroundColor(BubombTheme.textSecondary)
                TextField("--new-window", text: $appArgs)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var urlConfigurationForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Open URL Configuration")
                .font(.subheadline.bold())
                .foregroundColor(BubombTheme.accentOrange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Web Destination URL:").font(.caption).foregroundColor(BubombTheme.textSecondary)
                HStack {
                    TextField("https://", text: $urlString)
                        .textFieldStyle(.roundedBorder)

                    // URL Validation badge
                    if case .success = PathValidator.validateURL(urlString) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(BubombTheme.successGreen)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(BubombTheme.failureRed)
                    }
                }
            }

            Text("Detonating this payload will instantly open the validated destination in your default browser.")
                .font(.caption)
                .foregroundColor(BubombTheme.textSecondary)
        }
    }

    private var scriptConfigurationForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Run Script Configuration")
                .font(.subheadline.bold())
                .foregroundColor(BubombTheme.accentOrange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Script File:").font(.caption).foregroundColor(BubombTheme.textSecondary)
                HStack {
                    TextField("/path/to/script.sh", text: $scriptPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse...") {
                        chooseScript()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Arguments:").font(.caption).foregroundColor(BubombTheme.textSecondary)
                TextField("--env production --verbose", text: $scriptArgs)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Working Directory:").font(.caption).foregroundColor(BubombTheme.textSecondary)
                HStack {
                    TextField("(Optional directory)", text: $scriptWorkDir)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse...") {
                        chooseDirectory(target: $scriptWorkDir)
                    }
                }
            }
        }
    }

    private var sequenceConfigurationForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sequence Steps (\(sequenceSteps.count))")
                    .font(.subheadline.bold())
                    .foregroundColor(BubombTheme.accentOrange)
                Spacer()
                Button("+ Add Step") {
                    tempStep = SequenceStep(name: "Step \(sequenceSteps.count + 1)", action: .runCommand(command: "echo 'Step'", workingDirectory: nil, timeoutSeconds: 30))
                    editingStepIndex = nil
                    showStepEditor = true
                }
                .buttonStyle(.bordered)
            }

            Toggle("Stop sequence immediately if any step fails", isOn: $sequenceStopOnError)
                .font(.caption)
                .foregroundColor(BubombTheme.textSecondary)

            if sequenceSteps.isEmpty {
                Text("No steps configured. Click '+ Add Step' to build your multi-action detonation sequence.")
                    .font(.caption)
                    .foregroundColor(BubombTheme.textMuted)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(sequenceSteps.enumerated()), id: \.element.id) { index, step in
                        HStack(spacing: 8) {
                            Text("\(index + 1).")
                                .font(.caption.bold())
                                .foregroundColor(BubombTheme.accentOrange)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.name)
                                    .font(.subheadline.bold())
                                    .foregroundColor(BubombTheme.textPrimary)
                                Text("[\(step.actionTypeTitle)] \(step.summary)")
                                    .font(.caption)
                                    .foregroundColor(BubombTheme.textSecondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Button(action: {
                                if index > 0 {
                                    sequenceSteps.swapAt(index, index - 1)
                                }
                            }) {
                                Image(systemName: "arrow.up").font(.caption)
                            }
                            .disabled(index == 0)

                            Button(action: {
                                if index < sequenceSteps.count - 1 {
                                    sequenceSteps.swapAt(index, index + 1)
                                }
                            }) {
                                Image(systemName: "arrow.down").font(.caption)
                            }
                            .disabled(index == sequenceSteps.count - 1)

                            Button(action: {
                                tempStep = step
                                editingStepIndex = index
                                showStepEditor = true
                            }) {
                                Image(systemName: "pencil").font(.caption)
                            }

                            Button(action: {
                                sequenceSteps.remove(at: index)
                            }) {
                                Image(systemName: "trash").font(.caption).foregroundColor(BubombTheme.failureRed)
                            }
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }

    // MARK: - Safety Notice

    private var safetyNoticeSection: some View {
        let currentPayload = assemblePayload()
        let risk = currentPayload.safetyRisk

        return Group {
            if risk.isDestructive {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .foregroundColor(BubombTheme.failureRed)
                    Text("Destructive command detected: \(risk.warningMessage ?? ""). Bubomb will confirm before detonation.")
                        .font(.caption)
                        .foregroundColor(BubombTheme.failureRed)
                }
                .padding(10)
                .background(BubombTheme.failureRed.opacity(0.12))
                .cornerRadius(8)
            } else if let warning = risk.warningMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(BubombTheme.accentAmber)
                    Text("Safety notice: \(warning)")
                        .font(.caption)
                        .foregroundColor(BubombTheme.accentAmber)
                }
                .padding(10)
                .background(BubombTheme.accentAmber.opacity(0.12))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if let feedback = feedbackMessage {
                HStack {
                    Image(systemName: isErrorFeedback ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(isErrorFeedback ? BubombTheme.failureRed : BubombTheme.successGreen)
                    Text(feedback)
                        .font(.caption.bold())
                        .foregroundColor(isErrorFeedback ? BubombTheme.failureRed : BubombTheme.successGreen)
                    Spacer()
                }
            }

            HStack(spacing: 14) {
                Button(action: {
                    savePayload()
                }) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Save Payload")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(BubombTheme.accentOrange)
                .keyboardShortcut("s", modifiers: .command)

                Button(action: {
                    detonateOrConfirm()
                }) {
                    HStack {
                        Image(systemName: "flame.fill")
                        Text(executor.currentState.isRunning ? "Detonating..." : "Test Payload")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(BubombTheme.accentAmber)
                .disabled(executor.currentState.isRunning)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .bubombCard()
    }

    // MARK: - Actions & File Pickers

    private func assemblePayload() -> Payload {
        let type: PayloadType
        switch selectedTypeIndex {
        case 0:
            let args = shellArgs.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            let dir = shellWorkDir.isEmpty ? nil : shellWorkDir
            let timeout = shellTimeout > 0 ? shellTimeout : nil
            type = .shellCommand(ShellConfig(
                command: shellCommand,
                shellPath: shellPath,
                arguments: args,
                workingDirectory: dir,
                environmentVariables: envVars,
                timeoutSeconds: timeout
            ))
        case 1:
            let args = appArgs.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            type = .openApplication(AppConfig(applicationPath: appPath, arguments: args))
        case 2:
            type = .openURL(URLConfig(urlString: urlString))
        case 3:
            let args = scriptArgs.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            let dir = scriptWorkDir.isEmpty ? nil : scriptWorkDir
            let timeout = scriptTimeout > 0 ? scriptTimeout : nil
            type = .runScript(ScriptConfig(
                scriptPath: scriptPath,
                arguments: args,
                workingDirectory: dir,
                timeoutSeconds: timeout
            ))
        case 4:
            type = .sequence(SequenceConfig(steps: sequenceSteps, stopOnError: sequenceStopOnError))
        default:
            type = .shellCommand(ShellConfig())
        }

        return Payload(
            name: payloadName.trimmingCharacters(in: .whitespaces).isEmpty ? "My Action" : payloadName,
            type: type
        )
    }

    private func savePayload() {
        let payload = assemblePayload()
        do {
            try payload.validate()
            settingsStore.setActivePayload(payload)
            feedbackMessage = "Payload '\(payload.name)' saved and armed!"
            isErrorFeedback = false
        } catch {
            feedbackMessage = error.localizedDescription
            isErrorFeedback = true
        }
    }

    private func detonateOrConfirm() {
        let payload = assemblePayload()
        do {
            try payload.validate()
        } catch {
            feedbackMessage = error.localizedDescription
            isErrorFeedback = true
            return
        }

        let alwaysConfirm = settingsStore.settings.confirmDestructiveActions
        let (requiresConfirm, reason) = SafetyPolicy.requiresConfirmation(
            command: shellCommand,
            userSettingAlwaysConfirmDestructive: alwaysConfirm || payload.requiresConfirmation
        )

        if requiresConfirm {
            pendingDestructiveActionReason = reason
            showDestructiveConfirmation = true
        } else {
            executeDetonation(bypassConfirmation: false)
        }
    }

    private func executeDetonation(bypassConfirmation: Bool) {
        let payload = assemblePayload()
        Task {
            do {
                _ = try await executor.detonate(payload: payload, ignoreSafetyConfirmation: bypassConfirmation)
                await MainActor.run {
                    feedbackMessage = "Detonation complete!"
                    isErrorFeedback = false
                }
            } catch {
                await MainActor.run {
                    feedbackMessage = "Detonation error: \(error.localizedDescription)"
                    isErrorFeedback = true
                }
            }
        }
    }

    private func loadFromActivePayload() {
        guard let payload = settingsStore.settings.activePayload else {
            payloadName = "Quick Build"
            shellCommand = "echo 'Boom! Bubomb is ready.'"
            return
        }

        payloadName = payload.name
        switch payload.type {
        case .shellCommand(let cfg):
            selectedTypeIndex = 0
            shellCommand = cfg.command
            shellPath = cfg.shellPath
            shellWorkDir = cfg.workingDirectory ?? ""
            shellArgs = cfg.arguments.joined(separator: " ")
            shellTimeout = cfg.timeoutSeconds ?? 0
            envVars = cfg.environmentVariables
        case .openApplication(let cfg):
            selectedTypeIndex = 1
            appPath = cfg.applicationPath
            appArgs = cfg.arguments.joined(separator: " ")
        case .openURL(let cfg):
            selectedTypeIndex = 2
            urlString = cfg.urlString
        case .runScript(let cfg):
            selectedTypeIndex = 3
            scriptPath = cfg.scriptPath
            scriptArgs = cfg.arguments.joined(separator: " ")
            scriptWorkDir = cfg.workingDirectory ?? ""
            scriptTimeout = cfg.timeoutSeconds ?? 0
        case .sequence(let cfg):
            selectedTypeIndex = 4
            sequenceSteps = cfg.steps
            sequenceStopOnError = cfg.stopOnError
        }
    }

    private func chooseApplication() {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK, let url = panel.url {
            appPath = url.path
            if payloadName.isEmpty || payloadName == "Quick Build" {
                payloadName = url.deletingPathExtension().lastPathComponent
            }
        }
        #endif
    }

    private func chooseScript() {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            scriptPath = url.path
            if payloadName.isEmpty || payloadName == "Quick Build" {
                payloadName = url.lastPathComponent
            }
        }
        #endif
    }

    private func chooseDirectory(target: Binding<String>) {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            target.wrappedValue = url.path
        }
        #endif
    }
}
