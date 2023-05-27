//
// Created by Shukant Pal on 5/20/23.
//

#include "internal.h"
#include "model_loader.h"

#import <CoreML/CoreML.h>

namespace lens
{

const size_t EXPECTED_ROWS = 480;
const size_t EXPECTED_COLS = 640;
const size_t EXPECTED_CHANNELS = 3;

const int OUT_ROWS = EXPECTED_ROWS / 4;
const int OUT_COLS = EXPECTED_COLS / 4;
const int OUT_LANDMARKS = 5;

class center_face_impl : public center_face
{
public:
    explicit center_face_impl(MLModel const *);
    ~center_face_impl() noexcept override;
    void run(const cv::Mat& image,
             cv::Mat& heatmap,
             std::tuple<cv::Mat, cv::Mat>& scales,
             std::tuple<cv::Mat, cv::Mat>& offsets,
             std::vector<cv::Mat>& landmarks) override;
private:
    MLModel const* model;
};

center_face_impl::center_face_impl(const MLModel *model) :
    model(model)
{ }

center_face_impl::~center_face_impl() noexcept
{
    [this->model release];
    this->model = nullptr;
}

void center_face_impl::run(const cv::Mat &image,
                           cv::Mat& heatmap,
                           std::tuple<cv::Mat, cv::Mat>& scales,
                           std::tuple<cv::Mat, cv::Mat>& offsets,
                           std::vector<cv::Mat>& landmarks)
{
    assert(image.cols == EXPECTED_COLS);
    assert(image.rows == EXPECTED_ROWS);
    assert(image.channels() == EXPECTED_CHANNELS);
    assert(landmarks.size() == OUT_LANDMARKS * 2);

    size_t elems = image.total() * image.channels();

    NSError *error = nil;
    MLMultiArray *image_data = [[MLMultiArray alloc]
                                initWithDataPointer: reinterpret_cast<void *>(image.data)
                                              shape:@[@1, @(image.rows), @(image.cols), @(image.channels())]
                                           dataType:MLMultiArrayDataTypeFloat
                                            strides:@[@(elems), @(image.cols * image.channels()), @(image.channels()), @1]
                                        deallocator:nil
                                              error: &error];
    if (error)
    {
        NSLog(@"Failed to prepare image input: %@", error);
        @throw error;
    }

    auto options = @{
            @"input.1": [MLFeatureValue featureValueWithMultiArray:image_data]
    };
    MLDictionaryFeatureProvider* input_provider = [[MLDictionaryFeatureProvider alloc]
                                                   initWithDictionary:options
                                                                error:&error];
    id<MLFeatureProvider> input = input_provider;

    @autoreleasepool
    {
        id<MLFeatureProvider> output = [this->model predictionFromFeatures:input error:&error];

        if (error)
        {
            NSLog(@"Failed to execute face-swap model: %@", error);
            @throw error;
        }

        MLMultiArray* heatmap_data = [[output featureValueForName:@"537"] multiArrayValue];
        MLMultiArray* scales_data = [[output featureValueForName:@"538"] multiArrayValue];
        MLMultiArray* offsets_data = [[output featureValueForName:@"539"] multiArrayValue];
        MLMultiArray* landmarks_data = [[output featureValueForName:@"540"] multiArrayValue];

        auto* heatmap_ptr = reinterpret_cast<float*>([heatmap_data dataPointer]);
        auto* scales_ptr = reinterpret_cast<float*>([scales_data dataPointer]);
        auto* offsets_ptr = reinterpret_cast<float*>([offsets_data dataPointer]);
        auto* landmarks_ptr = reinterpret_cast<float*>([landmarks_data dataPointer]);

        cv::Mat(OUT_ROWS, OUT_COLS, CV_32FC1, heatmap_ptr)
                .copyTo(heatmap);
        cv::Mat(OUT_ROWS, OUT_COLS, CV_32FC1, scales_ptr)
                .copyTo(std::get<0>(scales));
        cv::Mat(OUT_ROWS, OUT_COLS, CV_32FC1, scales_ptr + OUT_ROWS*OUT_COLS)
                .copyTo(std::get<1>(scales));
        cv::Mat(OUT_ROWS, OUT_COLS, CV_32FC1, offsets_ptr)
                .copyTo(std::get<0>(offsets));
        cv::Mat(OUT_ROWS, OUT_COLS, CV_32FC1, offsets_ptr + OUT_ROWS*OUT_COLS)
                .copyTo(std::get<1>(offsets));

        for (int i = 0; i < OUT_LANDMARKS * 2; i++)
        {
            cv::Mat(OUT_ROWS, OUT_COLS, CV_32FC1, landmarks_ptr + OUT_ROWS*OUT_COLS*i)
                    .copyTo(landmarks[i]);
        }
    }

    [input_provider release];
    [image_data release];
}

std::unique_ptr<center_face> center_face::build(const std::string& path)
{
    MLModel* model = load_model(path, true);

    if (!model)
        return nullptr;

    return std::unique_ptr<center_face>(new center_face_impl(model));
}

}
