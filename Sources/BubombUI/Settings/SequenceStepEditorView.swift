import SwiftUI
import BubombCore
#if canImport(AppKit)
import AppKit
#endif

/// Sheet or inline editor for an individual Sequence Step.
public struct SequenceStepEditorView: View {
    @Binding var step: SequenceStep
    var onSave: () -> Void
    var onCancel: () -> Void

    @State private var stepTypeIndex: Int = 0
    @State private var appPath: String = ""
    @State private var urlString: String = "https://"
    @State private var commandString: String = ""
    @State private var commandWorkDir: String = ""
    @State private var scriptPath: String = ""
    @State private var scriptArgs: String = ""

    public init(step: Binding<SequenceStep>, onSave: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self._step = step
        self.onSave = onSave
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Step")
                .font(.headline)
                .foregroundColor(BubombTheme.textPrimary)

            TextField("Step Name", text: $step.name)
                .textFieldStyle(.roundedBorder)

            Picker("Action Type", selection: $stepTypeIndex) {
                Text("Open Application").tag(0)
                Text("Open URL").tag(1)
                Text("Run Command").tag(2)
                Text("Run Script").tag(3)
            }
            .pickerStyle(.segmented)

            Divider().background(BubombTheme.borderSubtle)

            Group {
                if stepTypeIndex == 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Application Path:").font(.caption).foregroundColor(BubombTheme.textSecondary)
                        HStack {
                            TextField("/Applications/Safari.app", text: $appPath)
                                .textFieldStyle(.roundedBorder)
                            Button("Choose...") {
                                chooseApplication()
                            }
                        }
                    }
                } else if stepTypeIndex == 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("URL Destination:").font(.caption).foregroundColor(BubombTheme.textSecondary)
                        TextField("https://apple.com", text: $urlString)
                            .textFieldStyle(.roundedBorder)
                    }
                } else if stepTypeIndex == 2 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Shell Command:").font(.caption).foregroundColor(BubombTheme.textSecondary)
                        TextField("e.g. npm run build", text: $commandString)
                            .textFieldStyle(.roundedBorder)
                        Text("Working Directory (Optional):").font(.caption).foregroundColor(BubombTheme.textSecondary)
                        TextField("/path/to/project", text: $commandWorkDir)
                            .textFieldStyle(.roundedBorder)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Script Path:").font(.caption).foregroundColor(BubombTheme.textSecondary)
                        HStack {
                            TextField("/path/to/script.sh", text: $scriptPath)
                                .textFieldStyle(.roundedBorder)
                            Button("Browse...") {
                                chooseScript()
                            }
                        }
                        Text("Arguments (Space separated):").font(.caption).foregroundColor(BubombTheme.textSecondary)
                        TextField("--verbose", text: $scriptArgs)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            Spacer()

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save Step") {
                    commitStep()
                    onSave()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(BubombTheme.accentOrange)
            }
        }
        .padding(20)
        .frame(width: 460, height: 350)
        .background(BubombTheme.surface)
        .onAppear {
            loadFromStep()
        }
    }

    private func loadFromStep() {
        switch step.action {
        case .openApplication(let path):
            stepTypeIndex = 0
            appPath = path
        case .openURL(let url):
            stepTypeIndex = 1
            urlString = url
        case .runCommand(let cmd, let workDir, _):
            stepTypeIndex = 2
            commandString = cmd
            commandWorkDir = workDir ?? ""
        case .runScript(let path, let args, _, _):
            stepTypeIndex = 3
            scriptPath = path
            scriptArgs = args.joined(separator: " ")
        }
    }

    private func commitStep() {
        switch stepTypeIndex {
        case 0:
            step.action = .openApplication(applicationPath: appPath)
        case 1:
            step.action = .openURL(urlString: urlString)
        case 2:
            let dir = commandWorkDir.isEmpty ? nil : commandWorkDir
            step.action = .runCommand(command: commandString, workingDirectory: dir, timeoutSeconds: 30)
        case 3:
            let args = scriptArgs.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            step.action = .runScript(scriptPath: scriptPath, arguments: args, workingDirectory: nil, timeoutSeconds: 60)
        default:
            break
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
            if step.name.isEmpty || step.name == "New Step" {
                step.name = url.deletingPathExtension().lastPathComponent
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
            if step.name.isEmpty || step.name == "New Step" {
                step.name = url.lastPathComponent
            }
        }
        #endif
    }
}
