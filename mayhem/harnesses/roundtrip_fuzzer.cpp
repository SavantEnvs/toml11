#include <toml.hpp>

#include <cstddef>
#include <cstdint>
#include <string>

// Parses with the newest supported spec (TOML v1.1.0) into the insertion-ordered
// value type, then re-serializes the document and parses the output again.
extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    const toml::spec s = toml::spec::v(1, 1, 0);
    std::string src(reinterpret_cast<const char *>(data), size);

    const auto res = toml::try_parse_str<toml::ordered_type_config>(src, s);
    if(res.is_err())
    {
        return -1;
    }

    const std::string out = toml::format(res.unwrap(), s);
    const auto again = toml::try_parse_str<toml::ordered_type_config>(out, s);
    (void)again;
    return 0;
}
