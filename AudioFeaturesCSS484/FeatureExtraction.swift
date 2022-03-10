//
//  FeatureExtraction.swift
//  Audio Recognition CSS484
//
//  Created by Jon Caceres, Derek Slater on 3/3/22.
//

import Foundation
import AVFoundation
import CoreML
import Accelerate

struct SoundFileData {
    var fileName: String?
    var buffers: Buffer?
    
    init(fileName: String?, buffers: Buffer?) {
        self.fileName = fileName
        self.buffers = buffers
    }
}

struct Buffer {
    var amplitude: [Float]?
    var magnitude: [Float]?
    
    var count: Int? {
        return magnitude?.count
    }
    
    init(amplitude: [Float]?, magnitude: [Float]?) {
        self.amplitude = amplitude
        self.magnitude = magnitude
    }
}

struct Features {
    var fileName: String
    var energyDistribution: Float
    var zeroCrossing: Double
    var averageEnergy: Double
    
    init(fileName: String, energyDistribution: Float, zeroCrossing: Double, averageEnergy: Double) {
        self.fileName = fileName
        self.energyDistribution = energyDistribution
        self.zeroCrossing = zeroCrossing
        self.averageEnergy = averageEnergy
    }
    
    
}

enum FeatureError: Error {
    case defaultError
}

class FeatureExtraction {
    
    var audioPlayer: AVAudioPlayer!
    var audioFile: AVAudioFile!
    var features = [Features]()
    var buffers = [Buffer]()
    
    let ml = MachineLearning()
    
//    func getSampleRate(audioFile: String) -> Int {
//        guard let audioData = Bundle.main.path(forResource: audioFile, ofType: nil) else {
//            print("could not find audio file")
//            return -1
//        }
//
//        let url = URL(fileURLWithPath: audioData)
//
//        do {
//            audioPlayer = try AVAudioPlayer(contentsOf: url)
//            //            audioPlayer.play()
//            guard let sampleRate = audioPlayer.settings["AVSampleRateKey"] as? Int else { return -1 }
//            return sampleRate
//        } catch {
//            print("error playing audio file")
//        }
//        return -1
//    }

    func transformAllFiles() async -> [Features] {
        
        let fm = FileManager.default
        let path = Bundle.main.resourcePath! + "/audioFiles"
        
        var convertedBuffer: [Float]? = nil
        
        do {
            let items = try fm.contentsOfDirectory(atPath: path)
            
            for item in items {
                
                var amplitude: AVAudioPCMBuffer? = nil
                do {
                    try amplitude = getAmplitude(file: item)
                } catch {
                    print("error")
                }
                
                convertedBuffer = convertBuffer(amplitude: amplitude!)
                let magnitude = getMagnitude(amplitude: amplitude!)
                let buffer = Buffer(amplitude: convertedBuffer, magnitude: magnitude)
                buffers.append(buffer)
                let averageEnergy1 = averageEnergy(amplitude: convertedBuffer!)
                let zeroCrossingRate1 = zeroCrossingRate(amplitude: convertedBuffer!)
                let sampleRate = getSampleRate(magnitude: magnitude, file: item)
                let energyDist = energyDistribution(magnitude: magnitude, sampleRate: sampleRate)
                
                features.append(Features(fileName: item, energyDistribution: energyDist, zeroCrossing: zeroCrossingRate1, averageEnergy: averageEnergy1))
            }
            features = features.sorted(by: { $0.fileName < $1.fileName })
            return features
        } catch {
            fatalError("could not transform files")
        }
    }
    
    func getMagnitude(amplitude: AVAudioPCMBuffer) -> [Float] {
        let frameCount = amplitude.frameLength
        let log2n = UInt(round(log2(Double(frameCount))))
        let bufferSizePOT = Int(1 << log2n)
        let inputCount = bufferSizePOT / 2
        let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2))
        
        var realp = [Float](repeating: 0, count: inputCount)
        var imagp = [Float](repeating: 0, count: inputCount)
        
        var output:DSPSplitComplex!
        realp.withUnsafeMutableBufferPointer { realp in
            imagp.withUnsafeMutableBufferPointer { imagp in
                output = DSPSplitComplex(realp: realp.baseAddress!, imagp: imagp.baseAddress!)
            }
        }
        
        let windowSize = bufferSizePOT
        var transferBuffer = [Float](repeating: 0, count: windowSize)
        var window = [Float](repeating: 0, count: windowSize)
        
        vDSP_hann_window(&window, vDSP_Length(windowSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul((amplitude.floatChannelData?.pointee)!, 1, window,
                  1, &transferBuffer, 1, vDSP_Length(windowSize))
        
        let temp = transferBuffer.withUnsafeBufferPointer({ $0 }).baseAddress!
        temp.withMemoryRebound(to: DSPComplex.self, capacity: transferBuffer.count) { (typeConvertedTransferBuffer) -> Void in
            /// Copies the contents of an interleaved complex vector C to a split complex vector Z; single precision.
            vDSP_ctoz(typeConvertedTransferBuffer, 2, &output, 1, vDSP_Length(inputCount))
        }
        
        /// Computes a forward or inverse in-place, single-precision real FFT.
        vDSP_fft_zrip(fftSetup!, &output, 1, log2n, FFTDirection(FFT_FORWARD))
        
        var magnitudes = [Float](repeating: 0.0, count: inputCount)
        
        /// Computes the squared magnitude value of each element in the supplied complex single-precision vector.
        vDSP_zvmags(&output, 1, &magnitudes, 1, vDSP_Length(inputCount))
                
        var normalizedMagnitudes = [Float](repeating: 0.0, count: inputCount)
        
        /// Multiplies a single-precision scalar value by a single-precision vector.
        vDSP_vsmul(sqrtq(magnitudes), 1, [2.0 / Float(inputCount)],&normalizedMagnitudes, 1, vDSP_Length(inputCount))
                
        vDSP_destroy_fftsetup(fftSetup)
        
        return normalizedMagnitudes
        
    }
    
    func sqrtq(_ x: [Float]) -> [Float] {
        var results = [Float](repeating: 0.0, count: x.count)
        vvsqrtf(&results, x, [Int32(x.count)])
        
        return results
    }
    
    func getAmplitude(file: String) throws -> AVAudioPCMBuffer {
                        
        guard let audioData = Bundle.main.path(forResource: "audioFiles/" + file, ofType: nil) else {
            print("could not find audio file")
            throw FeatureError.defaultError
        }
        
        let url = URL(fileURLWithPath: audioData)
        
        do {
            try audioFile = AVAudioFile(forReading: url)
        } catch {
            print("error playing audio file")
            throw FeatureError.defaultError
        }
        
        let audioFormat = audioFile.processingFormat
        let audioFrameCount = UInt32(audioFile.length)
        
        guard let amplitude = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: audioFrameCount) else {
            print("could not find amplitude")
            throw FeatureError.defaultError
        }
        do {
            try audioFile.read(into: amplitude, frameCount: audioFrameCount)
        } catch {
            throw FeatureError.defaultError
        }
//
        return amplitude
    }
    
    func convertBuffer(amplitude: AVAudioPCMBuffer) -> [Float] {
        let arraySize = Int(amplitude.frameLength)
        let samples = Array(UnsafeBufferPointer(start: amplitude.floatChannelData![0], count:arraySize))
        return samples
    }
    
    func averageEnergy(amplitude: [Float]) -> Double {
        
        var sum = 0.0
        
        for item in amplitude {
            sum += (Double(pow(item, 2)))
        }
        
        return (sum / Double(amplitude.count))
    }
    
    func zeroCrossingRate(amplitude: [Float]) -> Double {
                
        var signs = [Bool](repeating: false, count: 2)
        var sum: Double = 0
        let count: Double = Double(amplitude.count - 1)
        
        for index in 1...amplitude.count-1 {
            if amplitude[index] > 0 {
                signs[0] = true
            } else {
                signs[0] = false
            }
            
            if amplitude[index-1] > 0 {
                signs[1] = true
            } else {
                signs[1] = false
            }
            
            if signs[0] != signs[1] {
                sum += 2
            }
        }
        
        return sum / (2*(count))
        
    }
    
    func energyDistribution(magnitude: [Float], sampleRate: Float) -> Float {
        
        var numSum: Float = 0.0
        var denomSum: Float = 0.0
        
        for index in 0...magnitude.count - 1 {
            var k = Float(index)
            k /= Float(magnitude.count)
            k *= sampleRate
            numSum += k * magnitude[index]
            denomSum += magnitude[index]
        }
        
        return numSum/denomSum
    }

    func getSampleRate(magnitude: [Float], file: String) -> Float {
        let n = Float(magnitude.count)
        let length = Float(duration(for: file))
        return (n/length)
    }
    
    func duration(for resource: String) -> Double {
        
        guard let audioData = Bundle.main.path(forResource: "audioFiles/" + resource, ofType: nil) else {
            print("could not find audio file")
            return -1.0
        }
        
        let url = URL(fileURLWithPath: audioData)
        
        let asset = AVURLAsset(url: url)
        return Double(CMTimeGetSeconds(asset.duration))
    }
}
