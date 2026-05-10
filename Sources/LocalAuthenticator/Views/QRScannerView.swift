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
    var onCode: (String) -> Void

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

    private func handleCode(_ rawValue: String) {
        guard !didHandleCode else {
            return
        }

        didHandleCode = true
        onCode(rawValue)
    }
}

private struct CameraPreviewRepresentable: NSViewRepresentable {
    var onCode: (String) -> Void
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
        private let onCode: (String) -> Void
        private let onUnavailable: (String) -> Void
        private var didFindCode = false
        private var didConfigure = false

        init(onCode: @escaping (String) -> Void, onUnavailable: @escaping (String) -> Void) {
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

            guard let device = AVCaptureDevice.default(for: .video) else {
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

            guard session.canAddInput(input) else {
                notifyUnavailable("La caméra ne peut pas être utilisée par cette session.")
                return
            }

            session.beginConfiguration()
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                notifyUnavailable("Le scanner QR ne peut pas être configuré.")
                return
            }

            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
            session.commitConfiguration()

            didConfigure = true

            DispatchQueue.main.async { [weak preview, session] in
                preview?.previewLayer.session = session
            }

            session.startRunning()
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
            guard !didFindCode else { return }

            guard
                let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                object.type == .qr,
                let value = object.stringValue
            else {
                return
            }

            didFindCode = true
            stop()
            onCode(value)
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
                        .background(.black.opacity(0.55), in: Capsule())
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
                    .buttonStyle(.borderedProminent)
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
