//
// Created by Shukant Pal on 4/15/23.
//

#include "ml.h"

#import <CoreML/CoreML.h>

namespace lens
{

class face_swap_impl : public face_swap_model
{
public:
    explicit face_swap_impl(MLModel const *);
    ~face_swap_impl() noexcept override;
    void run(cv::Mat& in_face, cv::Mat& out_celebrity_face, cv::Mat& out_celebrity_face_mask) override;
private:
    MLModel const* model;
};

void face_swap_impl::run(cv::Mat &in_face, cv::Mat &out_celebrity_face, cv::Mat &out_celebrity_face_mask)
{
    NSError *error = nil;
    MLMultiArray *in_face_data = [[MLMultiArray alloc] initWithDataPointer: reinterpret_cast<void *>(in_face.data)
                                  shape:@[@1, @224, @224, @3]
                                  dataType:MLMultiArrayDataTypeFloat
                                  strides:@[@672, @672, @3, @1]
                                  deallocator:nil
                                  error: &error];

    if (error)
    {
        NSLog(@"Failed to prepare image input: %@", error);
        @throw error;
    }

    MLDictionaryFeatureProvider* dict = [[MLDictionaryFeatureProvider alloc] initWithDictionary:@{@"in_face:0": [MLFeatureValue featureValueWithMultiArray:in_face_data]} error:&error];
    id<MLFeatureProvider> input = dict;

    @autoreleasepool
    {
        id <MLFeatureProvider> output = [this->model predictionFromFeatures:input error:&error];

        if (error) {
            NSLog(@"Failed to execute face-swap model: %@", error);
            @throw error;
        }

        MLMultiArray *out_celebrity_face_data = [[output featureValueForName:@"out_celeb_face:0"] multiArrayValue];
        MLMultiArray *out_celebrity_face_mask_data = [[output featureValueForName:@"out_celeb_face_mask:0"] multiArrayValue];

        out_celebrity_face = cv::Mat(224, 224, CV_32FC3, [out_celebrity_face_data dataPointer]).clone();
        out_celebrity_face_mask = cv::Mat(224, 224, CV_32FC1, [out_celebrity_face_mask_data dataPointer]).clone();
    }

    [dict release];
    [in_face_data release];
}

face_swap_impl::face_swap_impl(MLModel const *model) :
    model(model)
{ }

face_swap_model::~face_swap_model()
{ }

face_swap_impl::~face_swap_impl() noexcept
{
    [this->model release];
    this->model = nullptr;
}

std::unique_ptr<face_swap_model> face_swap_model::build(const std::string& filename)
{
    NSString* const model_path = [NSString stringWithCString:filename.c_str() encoding:NSASCIIStringEncoding];
    NSURL* const model_url = [NSURL fileURLWithPath:model_path];
    MLModelConfiguration *configuration = [[MLModelConfiguration alloc] init];
    NSError* error = nil;

    configuration.computeUnits = MLComputeUnitsAll;
    NSURL* const compiled_model_url = [MLModel compileModelAtURL:model_url error:&error];

    if (error)
    {
        NSLog(@"Failed to compile model: %@", error);
        @throw error;
    }

    MLModel* const model = [MLModel modelWithContentsOfURL:compiled_model_url error:&error];

    if (error)
    {
        NSLog(@"%@", error);
        @throw error;
    }

    [configuration release];

    return std::unique_ptr<face_swap_model>(new face_swap_impl(model));
}

} // namespace lens