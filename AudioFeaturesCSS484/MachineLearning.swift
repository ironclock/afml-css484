//
//  MachineLearning.swift
//  AudioFeaturesCSS484
//
//  Created by Jon Caceres, Derek Slater on 3/3/22.
//

import Foundation
import CoreML

class Output: Identifiable {
    var fileName: String
    var isMusic: String
    var groundTruth: String
    
    init(fileName: String, isMusic: String, groundTruth: String) {
        self.fileName = fileName
        self.isMusic = isMusic
        self.groundTruth = groundTruth
    }
}

class MachineLearning {
    
    let audioModel = FifthModel()
    var audioOutput = [Output]()
        
    // Runs the features extracted from each audio file against our model
    // to predict if a file is music or speech
    //
    // - Parameters:
    //      - features: the features of all audio files
    // - Returns:
    //      - the output as an Output array containing predictions
    func runModel(features: [Features]) async -> [Output] {
        for feature in features {
            var groundTruth = "no"
            let fileName = String(feature.fileName.dropLast(4))
            let energyDistribution = Double(feature.energyDistribution)
            let zeroCrossingRate = feature.zeroCrossing
            let avgEnergy = feature.averageEnergy
            
            guard let output = try? audioModel.prediction(energyDistribution: energyDistribution, zeroCrossing: zeroCrossingRate, averageEnergy: avgEnergy) else {
                fatalError("could not run")
            }
            
            if(feature.fileName.contains("mu")) {
                groundTruth = "yes"
            }
            
            audioOutput.append(Output(fileName: fileName, isMusic: output.label, groundTruth: groundTruth))
            
        }
        return audioOutput
    }
}
