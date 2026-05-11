import SwiftUI
import AVFoundation

enum CameraAuthorizationState: Equatable {
    case checking
    case authorized
    case denied
    case restricted
    case unavailable(String)
}

struct QRScannerView: View {
    var onCode: (String) -> Bool

    @State private var authorizationState: CameraAuthorizationState = .checking
    @State private var scannerID = UUID()
    @State private var didHandleCode = false

    var body: some View {
        ZStack {
            switch authorizationState {
            case .checking:
                ScannerStatusView(
                    systemImage: "camera",
                    title: "Préparation de la caméra",
                    message: "Vérification de l'autorisation caméra.",
                    actionTitle: nil,
                    action: nil
                )

            case .authorized:
                CameraPreviewRepresentable(
                    onCode: handleCode,
                    onUnavailable: { message in
                        authorizationState = .unavailable(message)
                    }
                )
                .id(scannerID)
                .overlay(QRScannerOverlayView())

            case .denied:
                ScannerStatusView(
                    systemImage: "camera.fill",
                    title: "Caméra refusée",
                    message: "Autorisez la caméra dans Réglages Système pour scanner un QR code.",
                    actionTitle: "Réessayer",
                    action: checkAuthorization
                )

            case .restricted:
                ScannerStatusView(
                    systemImage: "lock.slash",
                    title: "Caméra restreinte",
                    message: "macOS ne permet pas à cette app d'accéder à la caméra.",
                    actionTitle: nil,
                    action: nil
                )

            case .unavailable(let message):
                ScannerStatusView(
                    systemImage: "video.slash",
                    title: "Caméra indisponible",
                    message: message,
                    actionTitle: "Relancer",
                    action: restartScanner
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.9))
        .onAppear(perform: checkAuthorization)
    }

    private func checkAuthorization() {
        authorizationState = .checking

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            restartScanner()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        restartScanner()
                    } else {
                        authorizationState = .denied
                    }
                }
            }

        case .denied:
            authorizationState = .denied

        case .restricted:
            authorizationState = .restricted

        @unknown default:
            authorizationState = .unavailable("L'état de la caméra n'est pas reconnu par cette version de macOS.")
        }
    }

    private func restartScanner() {
        didHandleCode = false
        scannerID = UUID()
        authorizationState = .authorized
    }

    private func handleCode(_ rawValue: String) -> Bool {
        guard !didHandleCode else {
            return true
        }

        let accepted = onCode(rawValue)
        if accepted {
            didHandleCode = true
        }
        return accepted
    }
}

private struct CameraPreviewRepresentable: NSViewRepresentable {
    var onCode: (String) -> Bool
    var onUnavailable: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode, onUnavailable: onUnavailable)
    }

    func makeNSView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        context.coordinator.configure(preview: view)
        return view
    }

    func updateNSView(_ nsView: CameraPreviewView, context: Context) {}

    static func dismantleNSView(_ nsView: CameraPreviewView, coordinator: Coordinator) {
        coordinator.stop()
        nsView.previewLayer.session = nil
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let session = AVCaptureSession()
        private let sessionQueue = DispatchQueue(label: "LocalAuthenticator.QRScanner.session")
        private let onCode: (String) -> Bool
        private let onUnavailable: (String) -> Void
        private var didFinishScan = false
        private var isHandlingCode = false
        private var didConfigure = false

        init(onCode: @escaping (String) -> Bool, onUnavailable: @escaping (String) -> Void) {
            self.onCode = onCode
            self.onUnavailable = onUnavailable
        }

        func configure(preview: CameraPreviewView) {
            preview.previewLayer.videoGravity = .resizeAspectFill

            sessionQueue.async { [weak self, weak preview] in
                guard let self, let preview else {
                    return
                }

                self.start(preview: preview)
            }
        }

        private func start(preview: CameraPreviewView) {
            if didConfigure {
                if !session.isRunning {
                    session.startRunning()
                }
                return
            }

            guard let device = preferredVideoDevice() else {
                notifyUnavailable("Aucune caméra n'a été détectée sur ce Mac.")
                return
            }

            let input: AVCaptureDeviceInput
            do {
                input = try AVCaptureDeviceInput(device: device)
            } catch {
                notifyUnavailable("Impossible d'ouvrir la caméra.")
                return
            }

            session.beginConfiguration()

            if session.canSetSessionPreset(.hd1280x720) {
                session.sessionPreset = .hd1280x720
            } else if session.canSetSessionPreset(.high) {
                session.sessionPreset = .high
            }

            configureDeviceForScanning(device)

            guard session.canAddInput(input) else {
                session.commitConfiguration()
                notifyUnavailable("La caméra ne peut pas être utilisée par cette session.")
                return
            }

            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                notifyUnavailable("Le scanner QR ne peut pas être configuré.")
                return
            }

            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)

            guard output.availableMetadataObjectTypes.contains(.qr) else {
                session.commitConfiguration()
                notifyUnavailable("Cette caméra ne prend pas en charge la détection de QR codes.")
                return
            }

            output.metadataObjectTypes = [.qr]
            session.commitConfiguration()

            didConfigure = true

            DispatchQueue.main.async { [weak preview, session] in
                preview?.previewLayer.session = session
            }

            session.startRunning()
        }

        private func preferredVideoDevice() -> AVCaptureDevice? {
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
                mediaType: .video,
                position: .unspecified
            )

            return discovery.devices.first(where: { $0.position == .front })
                ?? discovery.devices.first
                ?? AVCaptureDevice.default(for: .video)
        }

        private func configureDeviceForScanning(_ device: AVCaptureDevice) {
            do {
                try device.lockForConfiguration()

                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                } else if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }

                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }

                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                }

                #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
                if device.isSmoothAutoFocusSupported {
                    device.isSmoothAutoFocusEnabled = true
                }
                #endif

                device.unlockForConfiguration()
            } catch {
                return
            }
        }

        func stop() {
            sessionQueue.async { [weak self] in
                guard let self, self.session.isRunning else {
                    return
                }

                self.session.stopRunning()
            }
        }

        private func notifyUnavailable(_ message: String) {
            DispatchQueue.main.async {
                self.onUnavailable(message)
            }
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !didFinishScan, !isHandlingCode else { return }

            guard
                let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                object.type == .qr,
                let value = object.stringValue
            else {
                return
            }

            isHandlingCode = true
            let accepted = onCode(value)

            if accepted {
                didFinishScan = true
                stop()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                    guard let self, !self.didFinishScan else {
                        return
                    }

                    self.isHandlingCode = false
                }
            }
        }
    }
}

private struct QRScannerOverlayView: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height) * 0.58

            ZStack {
                Color.clear

                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.92), lineWidth: 3)
                    .frame(width: side, height: side)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.black.opacity(0.2), lineWidth: 1)
                    )

                VStack {
                    Spacer()

                    Text("Alignez le QR code dans le cadre")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                        }
                        .padding(.bottom, 18)
                }
            }
        }
    }
}

private struct ScannerStatusView: View {
    let systemImage: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 42))
                .foregroundStyle(.white.opacity(0.82))

            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            Text(message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.liquidGlassProminent)
                    .padding(.top, 4)
            }
        }
        .padding(24)
    }
}

final class CameraPreviewView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = previewLayer
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }
}
