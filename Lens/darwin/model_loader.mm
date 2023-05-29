//
// Created by Shukant Pal on 5/20/23.
//

#include <iostream>
#include <fstream>

#include "model_loader.h"

namespace fs = std::filesystem;

namespace lens
{

namespace model
{

fs::path compile(const fs::path &path)
{
    assert(path.extension().string() == ".mlmodel");

    NSFileManager* file_manager = [NSFileManager defaultManager];

    NSString *const model_path = [NSString stringWithCString:path.c_str()
                                                    encoding:NSASCIIStringEncoding];
    NSURL *const model_url = [NSURL fileURLWithPath:model_path];
    NSString *copied_path = [model_path stringByAppendingString:@"c"];
    NSError *error = nil;

    if (![file_manager fileExistsAtPath:copied_path])
    {
        NSURL *const compiled_model_url = [MLModel compileModelAtURL:model_url error:&error];

        if (error) {
            NSLog(@"Failed to compile model: %@", [error localizedDescription]);
            @throw error;
        }

        NSString *compiled_model_path = [compiled_model_url path];

        NSLog(@"Copying %@ to %@", compiled_model_path, copied_path);
        BOOL success = [file_manager copyItemAtPath:compiled_model_path
                                             toPath:copied_path
                                              error:&error];

        if (!success) {
            NSLog(@"%@", [error localizedDescription]);
            @throw error;
        }
    }

    std::string copied_path_str = [copied_path cStringUsingEncoding:NSASCIIStringEncoding];
    return {copied_path_str};
}

MLModel *load(const fs::path &path, bool gpu)
{
    assert(path.extension().string() == ".mlmodelc");

    MLModelConfiguration *configuration = [[MLModelConfiguration alloc] init];
    configuration.computeUnits = gpu ? MLComputeUnitsCPUAndGPU : MLComputeUnitsAll;

    NSError *error = nil;

    NSString *const model_path = [NSString stringWithCString:path.c_str()
                                                    encoding:NSASCIIStringEncoding];
    NSURL *const model_url = [NSURL fileURLWithPath:model_path];
    MLModel *const model = [MLModel modelWithContentsOfURL:model_url
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

} // namespace model

} // namespace lens