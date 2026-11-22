// Compile the actual patched Bar::handleSignal against a minimal surface boundary.
#include <json/json.h>
#include <spdlog/spdlog.h>
#include <cassert>
#include <csignal>
#include <cstdlib>
#include <fstream>
#include <memory>
#include <string>
#include <vector>
namespace waybar {
struct Output { std::string name; };
struct Module {
  int signal = 0;
  void refresh(int value) { signal = value; }
};
struct Bar {
  Json::Value config;
  Output* output;
  bool visible = true;
  int changes = 0;
  std::vector<std::shared_ptr<Module>> modules_all_;
  void setVisible(bool value) { visible = value; ++changes; }
  void handleSignal(int signal);
};
}
#include "handler.inc"

int main() {
  const auto* runtime = std::getenv("TMPDIR");
  assert(runtime);
  setenv("XDG_RUNTIME_DIR", runtime, 1);
  const auto path = std::string(runtime) + "/waybar-output-visibility.json";
  waybar::Output laptop{"laptop"}, dock{"dock"};
  waybar::Bar first, second;
  first.output = &laptop;
  second.output = &dock;
  first.config["visibility-signal"] = second.config["visibility-signal"] = 10;
  auto module = std::make_shared<waybar::Module>();
  first.modules_all_.push_back(module);
  auto publish = [&](const std::string& text) {
    std::ofstream(path) << text;
    first.handleSignal(SIGRTMIN + 10);
    second.handleSignal(SIGRTMIN + 10);
  };
  publish(R"({"laptop":false,"dock":true})");
  assert(!first.visible && second.visible);
  publish(R"({"laptop":true,"dock":false})");
  assert(first.visible && !second.visible);
  publish(R"({"laptop":true})");
  assert(first.visible && !second.visible);  // Missing dock entry leaves it alone.
  const auto unchanged = [&] { assert(first.changes == 3 && second.changes == 2); };
  for (const auto& text : {"{}", "[]", "null", "true", "broken", "{", R"({"laptop":"false","dock":1})", R"({"laptop":null})"}) {
    publish(text);
    unchanged();
  }
  std::remove(path.c_str());
  first.handleSignal(SIGRTMIN + 10);
  unchanged();
  unsetenv("XDG_RUNTIME_DIR");
  first.handleSignal(SIGRTMIN + 10);
  unchanged();
  first.handleSignal(SIGRTMIN + 8);
  assert(module->signal == SIGRTMIN + 8);
  unchanged();
}
