//
// Created by Shukant Pal on 5/20/23.
//

#include "internal.h"
#include "model_loader.h"

#import <CoreML/CoreML.h>

namespace lens
{

static const int NORM_FACE_DIM = 192;
static const int LDM_DIMS = 3;
static const int LDM_COUNT = 468;

class face_mesh_impl : public face_mesh
{
  public:
    explicit face_mesh_impl(MLModel const *);
    ~face_mesh_impl() noexcept override;
    void run(const cv::Mat &face, cv::Mat &landmarks) override;

  private:
    MLModel const *model;
};

face_mesh::~face_mesh() noexcept = default;

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
    assert(face.channels() == 4);

    cv::Mat resized_face;
    cv::resize(face, resized_face, cv::Size(NORM_FACE_DIM, NORM_FACE_DIM));
    cv::cvtColor(resized_face, resized_face, cv::COLOR_BGRA2BGR);
    resized_face.convertTo(resized_face, CV_32FC3, 1.0 / 255.0);

    NSError *error = nil;
    MLMultiArray *face_data =
        [[MLMultiArray alloc] initWithDataPointer:reinterpret_cast<void *>(resized_face.data)
                                            shape:@[
                                                @1,
                                                @(resized_face.rows),
                                                @(resized_face.cols),
                                                @(resized_face.channels())
                                            ]
                                         dataType:MLMultiArrayDataTypeFloat
                                          strides:@[
                                              @(resized_face.total() * resized_face.channels()),
                                              @(resized_face.cols * resized_face.channels()),
                                              @(resized_face.channels()),
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

        MLMultiArray *landmarks_data = [[output featureValueForName:@"conv2d_21"] multiArrayValue];
        auto *landmarks_ptr = reinterpret_cast<float *>([landmarks_data dataPointer]);

        cv::Mat(LDM_DIMS, LDM_COUNT, CV_32FC1, landmarks_ptr).copyTo(landmarks);
    }

    [input_provider release];
    [face_data release];
}

std::unique_ptr<face_mesh> face_mesh::build(const std::string &path)
{
    MLModel *model = load_model(path, true);

    if (!model)
        return nullptr;

    return std::unique_ptr<face_mesh>(new face_mesh_impl(model));
}

} // namespace lens