//
// Created by Shukant Pal on 5/20/23.
//

#pragma once

#include <string>

#import <CoreML/CoreML.h>


namespace lens
{

MLModel *load_model(const std::string& path, bool gpu = false);

} // namespace lens