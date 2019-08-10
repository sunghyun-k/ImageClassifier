//
//  ViewController.swift
//  ImageClassifier
//
//  Created by 김성현 on 07/08/2019.
//  Copyright © 2019 김성현. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    
    //MARK: View 프로퍼티
    
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var captureImageView: UIImageView!
    @IBOutlet weak var detectionLabel: UILabel!
    
    //MARK: AVCapture 프로퍼티
    
    private var session = AVCaptureSession()
    private var stillImageOutput = AVCapturePhotoOutput()
    private var videoPreviewLayer = AVCaptureVideoPreviewLayer()
    
    //MARK: Vision 프로퍼티
    
    private var requests = [VNRequest]()
    
    //MARK: 뷰 생명 주기
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAVCapture()
        setupLivePreview()
        setupVision()
    }
    
    //MARK: AV 캡쳐
    
    func setupAVCapture() {
        var deviceInput: AVCaptureDeviceInput
        
        // 세션을 고해상도 스틸 이미지 캡쳐로 설정합니다. 프리셋을 사용하여 간단하게 설정할 수 있습니다.
        session.sessionPreset = .medium
        
        // 비디오 장치를 선택해 입력 장치로 만듭니다.
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            print("후면 카메라에 접근할 수 없음")
            return
        }
        do {
            deviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            print("비디오 입력 장치를 생성할 수 없음: \(error)")
            return
        }
        
        guard session.canAddInput(deviceInput) else {
            print("세션에 비디오 입력 장치를 추가할 수 없음")
            session.commitConfiguration()
            return
        }
        session.addInput(deviceInput)
        
        guard session.canAddOutput(stillImageOutput) else {
            print("세션에 비디오 출력 장치를 추가할 수 없음")
            session.commitConfiguration()
            return
        }
        session.addOutput(stillImageOutput)
    }
    
    func setupLivePreview() {
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        
        videoPreviewLayer.videoGravity = .resizeAspect
        videoPreviewLayer.connection?.videoOrientation = .portrait
        previewView.layer.addSublayer(videoPreviewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
            
            DispatchQueue.main.async {
                self.videoPreviewLayer.frame = self.previewView.bounds
            }
        }
    }
    
    //MARK: Vision
    
    @discardableResult
    func setupVision() -> NSError? {
        // Vision 파트들을 설정합니다.
        let error: NSError! = nil
        
        guard let modelURL = Bundle.main.url(forResource: "RobotComponentClassifier", withExtension: "mlmodelc") else {
            return NSError(domain: "ViewController", code: -1, userInfo: [NSLocalizedDescriptionKey: "모델 파일을 찾을 수 없음"])
        }
        
        // Vision 모델로부터 VNCoreMLRequest를 생성하여 requests 배열에 넣습니다.
        do {
            let mlModel = try MLModel(contentsOf: modelURL)
            let visionModel = try VNCoreMLModel(for: mlModel)
            let objectRecognition = VNCoreMLRequest(model: visionModel, completionHandler: { (request, error) in
                DispatchQueue.main.async(execute: {
                    // 모든 UI 업데이트는 main queue에서 하십시오.
                    if let results = request.results {
                        self.showVisionRequestResults(results)
                    }
                })
            })
            requests = [objectRecognition]
        } catch let error as NSError {
            print("모델을 로드하는 중 오류 발생: \(error)")
        }
        
        return error
    }
    
    func showVisionRequestResults(_ results: [Any]) {
        // 가장 높은 첫번째와 두번째 식별 결과를 Label에 표시합니다.
        guard let top = results[0] as? VNClassificationObservation else { return }
        
        detectionLabel.text = "\(top.identifier) - \(top.confidence * 100)%"
    }
    
    //MARK: AVCapturePhotoCaptureDelegate
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // 캡쳐 이미지로부터 Data를 만듭니다.
        guard let imageData = photo.fileDataRepresentation() else {
            return
        }
        // 뷰에 스틸 이미지를 업데이트합니다.
        captureImageView.image = UIImage(data: imageData)
        
        // 이미지 요청 처리기를 만들고 요청을 수행합니다.
        let imageRequestHandler = VNImageRequestHandler(data: imageData, options: [:])
        do {
            try imageRequestHandler.perform(requests)
        } catch {
            print(error)
        }
        
    }
    
    //MARK: 액션
    
    @IBAction func takePhotoButtonTapped(_ sender: Any) {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        stillImageOutput.capturePhoto(with: settings, delegate: self)
    }
}
