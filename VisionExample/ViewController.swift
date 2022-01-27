//
//  ViewController.swift
//  VisionExample
//
//  Created by branch10480 on 2022/01/27.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {
  
  private let session = AVCaptureSession()
  private var previewLayer: AVCaptureVideoPreviewLayer!
  private let handler = VNSequenceRequestHandler()
  private let lockOnLayer = CALayer()
  
  @IBOutlet private weak var previewView: UIView!
  @IBOutlet private weak var rollLabel: UILabel!
  @IBOutlet private weak var yawLabel: UILabel!
  @IBOutlet private weak var pitchLabel: UILabel!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    self.session.startRunning()
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    self.session.stopRunning()
  }
  
  private func setup() {
    setupVideoProcessing()
    setupCameraPreview()
    setupTargetView()
  }
  
  private func setupVideoProcessing() {
    self.session.sessionPreset = .high
    
    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
          let input = try? AVCaptureDeviceInput(device: device) else {
            fatalError()
          }
    self.session.addInput(input)
    
    let videoDataOutput = AVCaptureVideoDataOutput()
    videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA)]
    videoDataOutput.alwaysDiscardsLateVideoFrames = true
    videoDataOutput.setSampleBufferDelegate(self, queue: .global())
    self.session.addOutput(videoDataOutput)
  }
  
  private func setupCameraPreview() {
    self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
    self.previewLayer.backgroundColor = UIColor.clear.cgColor
    self.previewLayer.videoGravity = .resizeAspectFill
    let rootLayer = self.previewView.layer
    rootLayer.masksToBounds = true
    self.previewLayer.frame = rootLayer.bounds
    rootLayer.addSublayer(self.previewLayer)
  }
  
  private func setupTargetView() {
    self.lockOnLayer.borderWidth = 4.0
    self.lockOnLayer.borderColor = UIColor.green.cgColor
    self.previewLayer.addSublayer(self.lockOnLayer)
  }
  
  private func handleRectangls(request: VNRequest, error: Error?) {
    guard let observation = request.results?.first as? VNFaceObservation else {
      DispatchQueue.main.async { [weak self] in
        self?.lockOnLayer.isHidden = true
      }
      return
    }
    
    DispatchQueue.main.async { [weak self] in
      self?.updateLabels(
        roll: observation.roll?.stringValue ?? "",
        yaw: observation.yaw?.stringValue ?? "",
        pitch: observation.pitch?.stringValue ?? ""
      )
      self?.lockOnLayer.isHidden = false
    }
    
    var boundingBox = observation.boundingBox
    boundingBox.origin.y = 1 - boundingBox.origin.y
    var convertedRect = self.previewLayer.layerRectConverted(fromMetadataOutputRect: boundingBox)
    convertedRect.origin.x -= convertedRect.width
    
    DispatchQueue.main.async {
      self.lockOnLayer.frame = convertedRect
    }
  }
    
  private func updateLabels(roll: String, yaw: String, pitch: String) {
    rollLabel.text = "roll\n" + roll
    yawLabel.text = "yaw\n" + yaw
    pitchLabel.text = "pitch\n" + pitch
  }
  
}
  
// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
  
   func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      return
    }
    let objectDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: handleRectangls(request:error:))
    try? self.handler.perform([objectDetectionRequest], on: pixelBuffer)
  }
  
}
