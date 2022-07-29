//
//  DocumentFinder.swift
//  Camera
//
//  Created by Shangxin Guo on 2018/10/22.
//  Copyright © 2018 Loong. All rights reserved.
//

import UIKit
#if canImport(Vision)
import Vision

public extension CGPoint {
    func map(toContentSize size: CGSize, invertingY: Bool) -> CGPoint {
        return .init(x: size.width * x, y: size.height * (invertingY ? (1 - y) : y))
    }
}

@available(iOS 11.0, *)
public extension VNRectangleObservation {
    @objc func topLeftVertex(toContentSize size: CGSize) -> CGPoint {
        return topLeft.map(toContentSize: size, invertingY: true)
    }
    @objc func topRightVertex(toContentSize size: CGSize) -> CGPoint {
        return topRight.map(toContentSize: size, invertingY: true)
    }
    @objc func bottomLeftVertex(toContentSize size: CGSize) -> CGPoint {
        return bottomLeft.map(toContentSize: size, invertingY: true)
    }
    @objc func bottomRightVertex(toContentSize size: CGSize) -> CGPoint {
        return bottomRight.map(toContentSize: size, invertingY: true)
    }
}

@available(iOS 11.0, *)
public class DocumentFinder: NSObject {
    @objc public var observation: VNRectangleObservation?
    
    @objc public func findDocumentRect(
        in image: UIImage,
        onCompletion block: @escaping (VNRectangleObservation?, Error?) -> Void
    ) {
        guard let img = image.cgImage else {
            block(nil, NSError(domain: "com.11visa.pandavisa.DocumentFinder.NoImageInput", code: 100, userInfo: nil))
            return
        }
        let handler = VNImageRequestHandler(cgImage: img, options: [:])
        let request = VNDetectRectanglesRequest { [weak self] req, error in
            let observation = req.results?.first as? VNRectangleObservation
            self?.observation = observation
            block(observation, error)
        }
        try? handler.perform([request])
    }
    
    /// 未完成
    @objc public func transform(
        _ image: UIImage,
        with observation: VNRectangleObservation,
        onCompletion block: @escaping (UIImage?, Error?) -> Void
    ) {
        guard let img = image.ciImage else {
            block(nil, NSError(domain: "com.11visa.pandavisa.DocumentFinder.NoImageInput", code: 100, userInfo: nil))
            return
        }
        guard let filter = CIFilter(
            name: "CIPerspectiveTransform",
            withInputParameters: [
                kCIInputImageKey: img,
                "inputTopLeft": CIVector(x: 0, y: 0),
                "inputTopRight": CIVector(x: 0, y: 0),
                "inputBottomRight": CIVector(x: 0, y: 0),
                "inputBottomLeft": CIVector(x: 0, y: 0)
            ]) else {
                block(nil, NSError(domain: "com.11visa.pandavisa.DocumentFinder.NoImageOutput", code: 101, userInfo: nil))
                return
            }
        
        let context = CIContext(options: nil)
        
        guard let outputCIImage = filter.outputImage,
            let cgImage = context.createCGImage(outputCIImage, from: outputCIImage.extent) else {
            block(nil, NSError(domain: "com.11visa.pandavisa.DocumentFinder.NoImageOutput", code: 101, userInfo: nil))
            return
        }
        
        let image = UIImage(cgImage: cgImage)
        
        block(image, nil)
    }
}

#endif
