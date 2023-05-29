//
// Created by Shukant Pal on 5/20/23.
//

#include "internal.h"
#include "model_loader.h"

#import <CoreML/CoreML.h>

namespace fs = std::filesystem;

namespace lens
{

class face_mesh_impl : public face_mesh
{
  public:
    explicit face_mesh_impl(MLModel const *);
    ~face_mesh_impl() noexcept override;
    void run(const cv::Mat &face, cv::Mat &landmarks) override;

  private:
    MLModel const *model;
};

face_mesh_impl::face_mesh_impl(const MLModel *model) :
    model(model)
{ }

face_mesh_impl::~face_mesh_impl() noexcept
{
    [this->model release];
    this->model = nullptr;
}

void face_mesh_impl::run(const cv::Mat &face, cv::Mat &landmarks)
{
    assert(face.channels() == 3);
    assert(face.rows == NORM_FACE_DIM);
    assert(face.cols == NORM_FACE_DIM);

    NSError *error = nil;
    MLMultiArray *face_data = [[MLMultiArray alloc]
        initWithDataPointer:reinterpret_cast<void *>(face.data)
                      shape:@[ @1, @(face.rows), @(face.cols), @(face.channels()) ]
                   dataType:MLMultiArrayDataTypeFloat
                    strides:@[
                        @(face.total() * face.channels()),
                        @(face.cols * face.channels()),
                        @(face.channels()),
                        @1
                    ]
                deallocator:nil
                      error:&error];

    if (error)
    {
        NSLog(@"Failed to prepare image input: %@", error);
        @throw error;
    }

    auto options = @{@"input_1" : [MLFeatureValue featureValueWithMultiArray:face_data]};
    MLDictionaryFeatureProvider *input_provider =
        [[MLDictionaryFeatureProvider alloc] initWithDictionary:options error:&error];

    id<MLFeatureProvider> input = input_provider;

    @autoreleasepool
    {
        id<MLFeatureProvider> output = [this->model predictionFromFeatures:input error:&error];

        if (error)
        {
            NSLog(@"Failed to execute face-swap model: %@", error);
            @throw error;
        }

        MLMultiArray *landmarks_data = [[output featureValueForName:@"conv2d_20"] multiArrayValue];
        auto *landmarks_ptr = reinterpret_cast<float *>([landmarks_data dataPointer]);

        cv::Mat(LDM_DIMS, LDM_COUNT, CV_32FC1, landmarks_ptr).copyTo(landmarks);
    }

    [input_provider release];
    [face_data release];
}

std::unique_ptr<face_mesh> face_mesh::build(const fs::path &model_dir)
{
    fs::path model_path = model_dir / fs::path("FaceMesh.mlmodel");
    auto compiled_path = model::compile(model_path);
    MLModel *model = model::load(compiled_path);

    if (!model)
        return nullptr;

    return std::unique_ptr<face_mesh>(new face_mesh_impl(model));
}

} // namespace lens