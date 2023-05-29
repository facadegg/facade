//
// Created by Shukant Pal on 5/20/23.
//

#pragma once

#include <filesystem>
#include <string>

#import <CoreML/CoreML.h>

namespace lens
{

namespace model
{

std::filesystem::path compile(const std::filesystem::path &);
MLModel *load(const std::filesystem::path &, bool gpu = false);

} // namespace model

} // namespace lens