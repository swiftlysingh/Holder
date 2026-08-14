//
//  DocumentScannerView.swift
//  Holder
//
//  Native iOS document capture. The scanner deliberately returns only the
//  first page as JPEG bytes; DocumentViewModel owns authentication, staging,
//  encryption, and persistence.
//

#if os(iOS) && canImport(VisionKit)
import SwiftUI
import UIKit
import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {
	let onScan: (Data) -> Void
	let onCancel: () -> Void
	let onFailure: () -> Void

	func makeCoordinator() -> Coordinator {
		Coordinator(parent: self)
	}

	func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
		let controller = VNDocumentCameraViewController()
		controller.delegate = context.coordinator
		return controller
	}

	func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
	}

	final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
		private let parent: DocumentScannerView
		private var finished = false

		init(parent: DocumentScannerView) {
			self.parent = parent
		}

		func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
			finish {
				parent.onCancel()
			}
		}

		func documentCameraViewController(
			_ controller: VNDocumentCameraViewController,
			didFinishWith scan: VNDocumentCameraScan
		) {
			guard scan.pageCount > 0,
				let jpegData = scan.imageOfPage(at: 0).jpegData(compressionQuality: 0.92) else {
				finish {
					parent.onFailure()
				}
				return
			}

			finish {
				parent.onScan(jpegData)
			}
		}

		func documentCameraViewController(
			_ controller: VNDocumentCameraViewController,
			didFailWithError error: Error
		) {
			// Do not surface platform errors: they can disclose implementation or
			// camera details and are not actionable to a person using Holder.
			finish {
				parent.onFailure()
			}
		}

		private func finish(_ action: () -> Void) {
			guard !finished else { return }
			finished = true
			action()
		}
	}
}
#endif
