// Known-answer probe: parses a fixed document with toml11 and prints what it found.
#include <toml.hpp>

#include <iostream>
#include <string>

int main()
{
    const std::string src =
        "title = \"toml11\"\n"
        "count = 0x1F\n"
        "ratio = 2.5e1\n"
        "ok = true\n"
        "when = 1979-05-27T07:32:00Z\n"
        "list = [1, 2, 3]\n"
        "[server]\n"
        "host = \"localhost\"\n"
        "ports = [8000, 8001]\n"
        "[[fruit]]\n"
        "name = \"apple\"\n"
        "[[fruit]]\n"
        "name = \"banana\"\n";

    const auto v = toml::parse_str(src);

    std::cout << "title=" << toml::find<std::string>(v, "title") << "\n";
    std::cout << "count=" << toml::find<int>(v, "count") << "\n";
    std::cout << "ratio=" << toml::find<double>(v, "ratio") << "\n";
    std::cout << "ok=" << (toml::find<bool>(v, "ok") ? "true" : "false") << "\n";
    std::cout << "when=" << toml::find<toml::offset_datetime>(v, "when") << "\n";
    int sum = 0;
    for(const auto& x : toml::find<std::vector<int>>(v, "list")) { sum += x; }
    std::cout << "list_sum=" << sum << "\n";
    std::cout << "host=" << toml::find<std::string>(v, "server", "host") << "\n";
    const auto ports = toml::find<std::vector<int>>(v, "server", "ports");
    std::cout << "ports=" << ports.at(0) << "," << ports.at(1) << "\n";
    const auto& fruit = toml::find(v, "fruit").as_array();
    std::cout << "fruit=" << toml::find<std::string>(fruit.at(0), "name") << ","
              << toml::find<std::string>(fruit.at(1), "name") << "\n";

    const auto bad = toml::try_parse_str("a = ");
    std::cout << "bad_is_err=" << (bad.is_err() ? 1 : 0) << "\n";

    const auto small = toml::parse_str("b = \"x\"\na = 1\n");
    std::cout << toml::format(small);
    return 0;
}
