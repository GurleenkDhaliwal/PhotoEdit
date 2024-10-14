import SwiftUI
import PhotosUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct ContentView: View {
    @State private var selectedImage: PhotosPickerItem? = nil
    
    @State private var originalImage: UIImage? // Keeps the unmodified original image
    @State private var inputImage: UIImage? // Used for displaying the currently adjusted image

    // Adjustments
    @State private var exposure: Float = 0.0
    @State private var brightness: Float = 0.0
    @State private var contrast: Float = 1.0
    @State private var brilliance: Float = 0.0
    @State private var highlights: Float = 0.0
    @State private var shadows: Float = 0.0
    @State private var blackPoint: Float = 0.0
    @State private var saturation: Float = 1.0
    @State private var vibrance: Float = 0.0
    @State private var warmth: Float = 6500.0
    @State private var tint: Float = 0.0
    
    @State private var selectedAdjustment: String? = nil
    @State private var selectedAdjustmentIndex: Int? = nil
    @State private var ciContext = CIContext()

    // Filters
    let filterOptions = ["Original", "Vivid", "Vivid Warm"]
    
    let adjustmentOptions = [
        ("sun.max", "Exposure", -2...2),
        ("circle.righthalf.fill", "Brilliance", -1...1),
        ("sparkles", "Brightness", -1...1),
        ("sun.max.fill", "Contrast", 0.5...2),
        ("sunrise.fill", "Highlights", -1...1),
        ("moon.fill", "Shadows", -1...1),
        ("drop.fill", "Black Point", 0...1),
        ("camera.filters", "Saturation", 0...2),
        ("sparkle", "Vibrance", -1...1),
        ("thermometer", "Warmth", 3000...8000),
        ("eyedropper.halffull", "Tint", -100...100)
    ]
    
    var body: some View {
        ZStack{
            Color.black
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    Button("Revert to Original") {
                        revertToOriginal()
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(8)
                    Spacer()
                }
                .padding()
                
                Spacer()
                
                // Image display section with gray placeholder when no image is selected
                if let inputImage = inputImage {
                    Image(uiImage: inputImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 300)
                        .padding()
                } else {
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(height: 300)
                            .cornerRadius(10)
                        
                        VStack {
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.white)
                            Text("Select an Image")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                    }
                    .padding()
                }

                // Photo picker
                PhotosPicker(selection: $selectedImage, matching: .images, photoLibrary: .shared()) {
                    Text("Choose Photo")
                }
                .onChange(of: selectedImage) { oldValue, newValue in
                    if let newValue = newValue {
                        Task {
                            try await loadImage(from: newValue)
                        }
                    }
                }
                
                // ScrollView for horizontal scrolling of adjustment icons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(adjustmentOptions.indices, id: \.self) { index in
                            Button(action: {
                                selectedAdjustmentIndex = index
                                selectedAdjustment = adjustmentOptions[index].1
                            }) {
                                VStack {
                                    Image(systemName: adjustmentOptions[index].0)
                                        .font(.title)
                                        .foregroundColor(selectedAdjustmentIndex == index ? .yellow : .gray)
                                    Text(adjustmentOptions[index].1)
                                        .font(.caption)
                                }
                                .padding()
                                .background(selectedAdjustmentIndex == index ? Color.yellow.opacity(0.3) : Color.clear)
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                }
                .frame(height: 120)
                
                // Show the corresponding slider only when an icon is selected
                if let adjustment = selectedAdjustment {
                    VStack {
                        Text(adjustment)
                            .font(.headline)
                        sliderForAdjustment(adjustment: adjustment)
                            .padding(.horizontal)
                    }
                }

                // Pre-built Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(filterOptions, id: \.self) { filterName in
                            Button(action: {
                                applyFilter(filterName: filterName)
                            }) {
                                VStack {
                                    filterPreview(for: filterName)
                                        .frame(width: 70, height: 70)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    Text(filterName)
                                        .foregroundColor(.white)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .padding()
                }
                .frame(height: 120)
            }
            .padding()
        }
    }

    // Save the adjusted image to the photo library
    func saveImage() {
        guard let inputImage = inputImage else { return }
        UIImageWriteToSavedPhotosAlbum(inputImage, nil, nil, nil)
    }
    
    // Revert all adjustments and filters back to the original image
    func revertToOriginal() {
        guard let original = originalImage else { return }
        inputImage = original
        resetAdjustments()
    }


    func scaleValue(_ value: Float, min: Float, max: Float) -> Float {
        return (value - min) / (max - min) * 100
    }

    func reverseScaleValue(_ value: Float, min: Float, max: Float) -> Float {
        return value / 100 * (max - min) + min
    }

    // Return the correct slider based on the currently selected adjustment
    @ViewBuilder
    func sliderForAdjustment(adjustment: String) -> some View {
        switch adjustment {
        case "Exposure":
            sliderForAdjustment(adjustment: "Exposure", value: $exposure, minValue: -2, maxValue: 2)
        case "Brilliance":
            sliderForAdjustment(adjustment: "Brilliance", value: $brilliance, minValue: -1, maxValue: 1)
        case "Brightness":
            sliderForAdjustment(adjustment: "Brightness", value: $brightness, minValue: -1, maxValue: 1)
        case "Contrast":
            sliderForAdjustment(adjustment: "Contrast", value: $contrast, minValue: 0.5, maxValue: 2)
        case "Highlights":
            sliderForAdjustment(adjustment: "Highlights", value: $highlights, minValue: -1, maxValue: 1)
        case "Shadows":
            sliderForAdjustment(adjustment: "Shadows", value: $shadows, minValue: -1, maxValue: 1)
        case "Black Point":
            sliderForAdjustment(adjustment: "Black Point", value: $blackPoint, minValue: 0, maxValue: 1)
        case "Saturation":
            sliderForAdjustment(adjustment: "Saturation", value: $saturation, minValue: 0, maxValue: 2)
        case "Vibrance":
            sliderForAdjustment(adjustment: "Vibrance", value: $vibrance, minValue: -1, maxValue: 1)
        case "Warmth":
            sliderForAdjustment(adjustment: "Warmth", value: $warmth, minValue: 3000, maxValue: 8000)
        case "Tint":
            sliderForAdjustment(adjustment: "Tint", value: $tint, minValue: -100, maxValue: 100)
        default:
            EmptyView()
        }
    }

    // New sliderForAdjustment function with min/max value parameters
    @ViewBuilder
    func sliderForAdjustment(adjustment: String, value: Binding<Float>, minValue: Float, maxValue: Float) -> some View {
        VStack {
            HStack {
                Slider(value: value, in: minValue...maxValue)
                    .onChange(of: value.wrappedValue) {
                        Task {
                            try await applyAdjustments()
                        }
                    }
                Text("\(Int(scaleValue(value.wrappedValue, min: minValue, max: maxValue)))")
                    .foregroundColor(.yellow)
                    .font(.system(size: 18))
                    .frame(width: 50, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    func filterPreview(for filterName: String) -> some View {
        if let originalImage = originalImage {
            let filteredImage = generateFilteredPreview(for: filterName, image: originalImage)
            Image(uiImage: filteredImage)
                .resizable()
                .scaledToFill()
        } else {
            Color.gray // Placeholder if no image is selected
        }
    }

    // Load image asynchronously using Swift 6 typed throws
    func loadImage(from item: PhotosPickerItem) async throws {
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    originalImage = image
                    inputImage = image
                    resetAdjustments()
                }
            }
        } catch {
            throw ImageLoadError.failedToLoadImage(error.localizedDescription)
        }
    }
    
    func resetAdjustments() {
        exposure = 0.0
        brightness = 0.0
        contrast = 1.0
        brilliance = 0.0
        highlights = 0.0
        shadows = 0.0
        blackPoint = 0.0
        saturation = 1.0
        vibrance = 0.0
        warmth = 6500.0
        tint = 0.0
    }

    // Apply adjustments and concurrency safety
    @MainActor
    func applyAdjustments() async throws {
        guard inputImage != nil else { return }
        
        let beginImage = CIImage(image: originalImage!)
        
        // Apply filters for each adjustment in the proper order
        let exposureFilter = CIFilter.exposureAdjust()
        exposureFilter.inputImage = beginImage
        exposureFilter.ev = exposure
        
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = exposureFilter.outputImage
        colorControls.brightness = brightness
        colorControls.contrast = contrast
        colorControls.saturation = saturation
        
        let highlightShadowAdjust = CIFilter.highlightShadowAdjust()
        highlightShadowAdjust.inputImage = colorControls.outputImage
        highlightShadowAdjust.highlightAmount = highlights
        highlightShadowAdjust.shadowAmount = shadows
        
        let vibranceFilter = CIFilter.vibrance()
        vibranceFilter.inputImage = highlightShadowAdjust.outputImage
        vibranceFilter.amount = vibrance
        
        // Simulating Black Point adjustment using contrast and brightness
        let blackPointFilter = CIFilter.colorControls()
        blackPointFilter.inputImage = vibranceFilter.outputImage
        blackPointFilter.brightness = brightness - blackPoint * 0.1
        blackPointFilter.contrast = contrast + blackPoint * 0.7
        
        let temperatureAndTint = CIFilter.temperatureAndTint()
        temperatureAndTint.inputImage = blackPointFilter.outputImage
        temperatureAndTint.neutral = CIVector(x: CGFloat(warmth), y: 0)
        temperatureAndTint.targetNeutral = CIVector(x: 6500 + CGFloat(tint * 3), y: 0)

        if let outputImage = temperatureAndTint.outputImage,
           let cgimg = ciContext.createCGImage(outputImage, from: outputImage.extent) {
            DispatchQueue.main.async {
                self.inputImage = UIImage(cgImage: cgimg, scale: originalImage!.scale, orientation: originalImage!.imageOrientation)
            }
        }
    }

    // Generate filtered image preview
    func generateFilteredPreview(for filterName: String, image: UIImage) -> UIImage {
        let ciImage = CIImage(image: image)
      
        switch filterName {
        case "Vivid":
            let vividFilter = CIFilter.colorControls()
            vividFilter.inputImage = ciImage
            vividFilter.saturation = 1.3
            vividFilter.contrast = 1.2
            vividFilter.brightness = 0.10
            
            // Apply vibrance to enhance muted colors
            let vibranceFilter = CIFilter.vibrance()
            vibranceFilter.inputImage = vividFilter.outputImage
            vibranceFilter.amount = 0.25  // Adjust vibrance level to desired intensity

            return applyFilter(filter: vibranceFilter, to: image)
            
        case "Vivid Warm":
            let vividFilter = CIFilter.colorControls()
            vividFilter.inputImage = ciImage
            vividFilter.saturation = 1.5
            vividFilter.contrast = 1.2
            vividFilter.brightness = 0.05
            
            let warmthFilter = CIFilter.temperatureAndTint()
            warmthFilter.inputImage = vividFilter.outputImage
            warmthFilter.neutral = CIVector(x: 7000, y: 0)
            return applyFilter(filter: warmthFilter, to: image)
            
        default:
            return image
        }
    }

    // Apply selected filter to the image
    func applyFilter(filterName: String) {
        guard let originalImage = originalImage else { return }
        inputImage = generateFilteredPreview(for: filterName, image: originalImage)
    }

    // Apply filter logic
    func applyFilter(filter: CIFilter, to image: UIImage) -> UIImage {
        if let outputImage = filter.outputImage,
           let cgimg = ciContext.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgimg, scale: image.scale, orientation: image.imageOrientation)
        }
        return image
    }
}

// Define possible image load error cases
enum ImageLoadError: Error {
    case failedToLoadImage(String)
}

#Preview {
    ContentView()
}

