import SwiftUI
import NetworkExtension

/// 首次配置的 3 步(对外仍是 3 步,证书内部拆成"下载"和"安装"两屏)
enum SetupStep: Int, CaseIterable {
    case welcome = 0  // 欢迎页
    case vpn = 1      // 步骤 1:VPN 权限
    case cert = 2     // 步骤 2a:下载证书(唤起 Safari)
    case install = 3  // 步骤 2b:安装描述文件
    case trust = 4    // 步骤 3:证书信任
    case done = 5     // 完成页

    /// 进度条:welcome 和 done 不显示;.cert 和 .install 合并算步骤 2,.trust 算步骤 3。
    var progressIndex: Int? {
        switch self {
        case .welcome, .done: return nil
        case .vpn: return 1
        case .cert, .install: return 2
        case .trust: return 3
        }
    }

    var title: String {
        switch self {
        case .welcome: return ""
        case .vpn: return "VPN Authorization"
        case .cert: return "Download Certificate"
        case .install: return "Install Profile"
        case .trust: return "Trust Certificate"
        case .done: return ""
        }
    }
}

struct FirstSetupView: View {
    @State private var currentStep: SetupStep = .welcome
    @State private var errorMessage: String? = nil
    @State private var isProcessing: Bool = false
    @State private var showInstallConfirm: Bool = false
    @State private var showTrustConfirm: Bool = false

    /// 配置完成回调,由 ContentView 监听 firstSetupCompleted 变化即可,这里不必显式传

    var body: some View {
        ZStack {
            // 整体淡入效果
            switch currentStep {
            case .welcome:
                welcomeView
                    .transition(.opacity)
            case .vpn, .cert, .install, .trust:
                progressView
                    .transition(.opacity)
            case .done:
                doneView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
        .alert("Error", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
            Button("OK") { errorMessage = nil }
        } message: { msg in
            Text(msg)
        }
        .alert("Confirm profile installed", isPresented: $showInstallConfirm) {
            Button("Installed") { currentStep = .trust }
            Button("Install", role: .cancel) { }
        } message: {
            Text("Please confirm that you have installed the profile in Settings → General → VPN & Device Management. If not, install it first, then confirm.")
        }
        .alert("Confirm certificate trust", isPresented: $showTrustConfirm) {
            Button("Trusted") { confirmTrust() }
            Button("Go to Settings", role: .cancel) { }
        } message: {
            Text("Please confirm that you have enabled the Location Spoofer CA trust setting in Settings → General → About → Certificate Trust Settings. If not, trust it first, then confirm.")
        }
    }

    // MARK: - 欢迎页

    private var welcomeView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "location.fill.viewfinder")
                .font(.system(size: 72))
                .foregroundColor(.blue)

            Text("Welcome to AnyDoor")
                .font(.largeTitle).fontWeight(.bold)

            Text("Finish setup in 3 steps and change your location with one tap.")
                .font(.title3)
                .foregroundColor(.secondary)

            Spacer()

            Button(action: { currentStep = .vpn }) {
                Text("Start Setup")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)

            Text("The setup process requires VPN permission and certificate installation. These are necessary steps to change your location.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
        }
    }

    // MARK: - 进度页(共用 vpn / cert / trust 三个步骤)

    private var progressView: some View {
        VStack(spacing: 32) {
            Spacer().frame(height: 40)

            // 进度条:1/3 → 2/3 → 3/3
            progressIndicator

            // 当前步骤标题
            Text(currentStep.title)
                .font(.title).fontWeight(.bold)

            // 步骤说明
            stepInstruction
                .padding(.horizontal, 32)

            Spacer()

            // 操作按钮
            stepActionButton
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
        }
    }

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { idx in
                Circle()
                    .fill(progressColor(at: idx))
                    .frame(width: 12, height: 12)
                if idx < 3 {
                    Rectangle()
                        .fill(progressColor(at: idx))
                        .frame(width: 40, height: 2)
                }
            }
        }
    }

    private func progressColor(at index: Int) -> Color {
        guard let current = currentStep.progressIndex else { return .gray.opacity(0.3) }
        return index <= current ? .blue : .gray.opacity(0.3)
    }

    @ViewBuilder
    private var stepInstruction: some View {
        switch currentStep {
        case .vpn:
            VStack(spacing: 12) {
                Text("In the system prompt, tap Allow and enter your device passcode.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue.opacity(0.6))
                    .padding(.top, 20)
            }
        case .cert:
            VStack(spacing: 12) {
                Text("Tap the button below. Safari will open and prompt you to install the certificate.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                Text("Follow the system prompts to download the certificate.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Text("If Safari says the certificate already exists or opens Trust Settings directly, the certificate is installed. Close Safari and continue to the next step.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        case .install:
            VStack(alignment: .leading, spacing: 14) {
                Text("After the certificate is downloaded, install it using the steps below:")
                    .font(.body)
                Text("① Open Settings on your iPhone")
                Text("② Tap the downloaded profile at the top")
                Text("③ Tap Install in the top right and follow the prompts")
                Text("④ Return to this app when finished")
                    .font(.body)
                    .foregroundColor(.blue)
                    .padding(.top, 8)
            }
        case .trust:
            VStack(alignment: .leading, spacing: 14) {
                Text("After downloading, you must manually trust the certificate:")
                    .font(.body)
                Text("① Open Settings")
                Text("② Go to General → About")
                Text("③ Scroll down to Certificate Trust Settings")
                Text("④ Enable Location Spoofer CA")
                Text("⑤ Tap Continue in the prompt")
                Text("Return to this app when finished")
                    .font(.body)
                    .foregroundColor(.blue)
                    .padding(.top, 8)
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var stepActionButton: some View {
        switch currentStep {
        case .vpn:
            Button(action: { triggerVPNSetup() }) {
                Text(isProcessing ? "Setting up..." : "Authorize VPN")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isProcessing ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(isProcessing)
        case .cert:
            Button(action: { triggerCertInstall() }) {
                Text(isProcessing ? "Opening..." : "Install Certificate")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isProcessing ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(isProcessing)
        case .install:
            Button(action: { showInstallConfirm = true }) {
                Text("Installed, Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        case .trust:
            Button(action: { showTrustConfirm = true }) {
                Text("I have trusted the certificate")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        default:
            EmptyView()
        }
    }

    // MARK: - 完成页

    private var doneView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            Text("Setup complete!")
                .font(.largeTitle).fontWeight(.bold)
            Text("You can now change your location with one tap.")
                .font(.title3)
                .foregroundColor(.secondary)
            Spacer()
            Button(action: { completeSetup() }) {
                Text("Start Using")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    // MARK: - 占位:D2/D3 实现

    private func triggerVPNSetup() {
        isProcessing = true

        if let manager = ContentView.vpnManager {
            startTunnelAndAdvance(manager: manager)
        } else {
            // 首次:vpnManager 还没就绪,当场安装配置再启动
            ContentView.installAndStartVPN { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let manager):
                        startTunnelAndAdvance(manager: manager)
                    case .failure(let error):
                        isProcessing = false
                        errorMessage = "VPN configuration installation failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    /// 启动 VPN tunnel,3 秒后检查连接状态,连上就推进到 .cert,否则报超时。
    private func startTunnelAndAdvance(manager: NETunnelProviderManager) {
        do {
            try manager.connection.startVPNTunnel()
            // 等待 3 秒看是否真的连上
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                isProcessing = false
                if manager.connection.status == .connected {
                    currentStep = .cert
                } else {
                    errorMessage = "VPN connection timed out, please try again or check your network."
                }
            }
        } catch {
            isProcessing = false
            errorMessage = "VPN failed to start: \(error.localizedDescription)"
        }
    }

    private func triggerCertInstall() {
        isProcessing = true

        CertificateInstaller.installCertificate { success, errMsg in
            DispatchQueue.main.async {
                isProcessing = false
                if success {
                    // Safari 已唤起,等用户从 Safari 回来后,先到"安装描述文件"步骤
                    UserDefaults.standard.set(true, forKey: "certDownloaded")
                    currentStep = .install
                } else {
                    errorMessage = errMsg ?? "Failed to launch certificate installation"
                }
            }
        }
    }

    private func confirmTrust() {
        // 手动确认信任(iOS 没有完美的"检测证书是否被信任"API)
        UserDefaults.standard.set(true, forKey: "certInstalled")
        UserDefaults.standard.set(true, forKey: "certTrusted")
        currentStep = .done
    }

    private func completeSetup() {
        UserDefaults.standard.set(true, forKey: "firstSetupCompleted")
        UserDefaults.standard.set(true, forKey: "certDownloaded")
        UserDefaults.standard.set(true, forKey: "certInstalled")
        UserDefaults.standard.set(true, forKey: "certTrusted")
    }
}
