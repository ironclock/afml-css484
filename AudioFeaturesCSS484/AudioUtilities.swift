/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Class containing methods for tone generation.
*/

import AVFoundation
import Accelerate

class AudioUtilities {
    
    // Returns an array of single-precision values for the specified audio resource.
    static func getAudioSamples(forResource: String,
                                withExtension: String) -> (naturalTimeScale: CMTimeScale,
                                                           data: [Float])? {
        
        guard let path = Bundle.main.url(forResource: forResource,
                                         withExtension: withExtension) else {
                                            return nil
        }
        
        let asset = AVAsset(url: path.absoluteURL)
        
        guard
            let reader = try? AVAssetReader(asset: asset),
            let track = asset.tracks.first else {
                return nil
        }
        
        let outputSettings: [String: Int] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVNumberOfChannelsKey: 1,
            AVLinearPCMIsBigEndianKey: 0,
            AVLinearPCMIsFloatKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsNonInterleaved: 1
        ]
        
        let output = AVAssetReaderTrackOutput(track: track,
                                              outputSettings: outputSettings)

        reader.add(output)
        reader.startReading()
        
        var samplesData = [Float]()
        
        while reader.status == .reading {
            if
                let sampleBuffer = output.copyNextSampleBuffer(),
                let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                
                    let bufferLength = CMBlockBufferGetDataLength(dataBuffer)
                
                    var data = [Float](repeating: 0,
                                       count: bufferLength / 4)
                    CMBlockBufferCopyDataBytes(dataBuffer,
                                               atOffset: 0,
                                               dataLength: bufferLength,
                                               destination: &data)
                
                    samplesData.append(contentsOf: data)
            }
        }

        return (naturalTimeScale: track.naturalTimeScale,
                data: samplesData)
    }
}

class SignalGenerator {
    private let engine = AVAudioEngine()
    
    /// The current page of single-precision audio samples
    private var page = [Float]()
    
    /// The object that provides audio samples.
    private let signalProvider: SignalProvider

    /// The sample rate for the input and output format.
    let sampleRate: CMTimeScale
    
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate),
                                            channels: 1)
    
    private lazy var srcNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
        for frame in 0..<Int(frameCount) {
            let value = self.getSignalElement()
            
            for buffer in ablPointer {
                let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                buf[frame] = value
            }
        }
        return noErr
    }
    
    init(signalProvider: SignalProvider, sampleRate: CMTimeScale) {
        self.signalProvider = signalProvider
        self.sampleRate = sampleRate
        
        engine.attach(srcNode)
        
        engine.connect(srcNode,
                       to: engine.mainMixerNode,
                       format: format)
        
        engine.connect(engine.mainMixerNode,
                       to: engine.outputNode,
                       format: format)
        
        engine.mainMixerNode.outputVolume = 0.5
    }
    
    public func start() throws {
        try engine.start()
    }
    
    private func getSignalElement() -> Float {
        if page.isEmpty {
            page = signalProvider.getSignal()
        }
        
        return page.isEmpty ? 0 : page.removeFirst()
    }
}

protocol SignalProvider {
    func getSignal() -> [Float]
}
