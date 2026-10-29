#include <toml.hpp>

#include <cstddef>
#include <cstdint>
#include <string>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    std::string s(reinterpret_cast<const char *>(data), size);
    const auto res = toml::try_parse_str(s);
    if(res.is_err())
    {
        return -1;
    }
    return 0;
}
