//
// Created by Shukant Pal on 5/20/23.
//

#include "model_loader.h"

namespace lens
{

MLModel *load_model(const std::string &path, bool gpu)
{
    if (!path.ends_with(".mlmodel"))
        throw std::runtime_error(path + " is not a CoreML model");

    NSString *const model_path = [NSString stringWithCString:path.c_str()
                                                    encoding:NSASCIIStringEncoding];
    NSURL *const model_url = [NSURL fileURLWithPath:model_path];
    MLModelConfiguration *configuration = [[MLModelConfiguration alloc] init];
    NSError *error = nil;

    configuration.computeUnits = gpu ? MLComputeUnitsCPUAndGPU : MLComputeUnitsAll;

    NSURL *const compiled_model_url = [MLModel compileModelAtURL:model_url error:&error];

    if (error)
    {
        NSLog(@"Failed to compile model: %@", [error localizedDescription]);
        @throw error;
    }

    MLModel *const model = [MLModel modelWithContentsOfURL:compiled_model_url
                                             configuration:configuration
                                                     error:&error];

    if (error)
    {
        NSLog(@"%@", [error localizedDescription]);
        @throw error;
    }

    [configuration release];

    return model;
}

} // namespace lens