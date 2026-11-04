// SPDX-License-Identifier: MIT
#pragma once
#include <algorithm>
#include <cmath>
#include <optional>
#include <vector>

namespace FullEdges {
struct Point { double x, y; };
struct Box { double x, y, w, h; };
inline bool contains(Box b, Point p) {
    return p.x >= b.x && p.x < b.x + b.w && p.y >= b.y && p.y < b.y + b.h;
}
// A shared geometric edge selects the neighbour. Its entire length is a portal,
// with proportional position along the destination edge, including dead corners.
inline std::optional<Point> cross(Box source, const std::vector<Box>& others, Point p, Point delta) {
    std::optional<Point> result;
    double first = 2;
    for (auto b : others) {
        auto attempt = [&](double t, bool horizontal, bool forward) {
            if (t < 0 || t > 1 || t >= first) return;
            first = t;
            if (horizontal) {
                double fraction = std::clamp((p.y + t * delta.y - source.y) / source.h, 0.0, 1.0);
                result = Point{forward ? b.x + 2 : b.x + b.w - 2,
                               b.y + std::clamp(fraction * b.h, 2.0, b.h - 2)};
            } else {
                double fraction = std::clamp((p.x + t * delta.x - source.x) / source.w, 0.0, 1.0);
                result = Point{b.x + std::clamp(fraction * b.w, 2.0, b.w - 2),
                               forward ? b.y + 2 : b.y + b.h - 2};
            }
        };
        bool overlapY = std::min(source.y + source.h, b.y + b.h) > std::max(source.y, b.y);
        bool overlapX = std::min(source.x + source.w, b.x + b.w) > std::max(source.x, b.x);
        if (overlapY && delta.x > 0 && std::abs(source.x + source.w - b.x) < 1)
            attempt((source.x + source.w - p.x) / delta.x, true, true);
        if (overlapY && delta.x < 0 && std::abs(source.x - b.x - b.w) < 1)
            attempt((source.x - p.x) / delta.x, true, false);
        if (overlapX && delta.y > 0 && std::abs(source.y + source.h - b.y) < 1)
            attempt((source.y + source.h - p.y) / delta.y, false, true);
        if (overlapX && delta.y < 0 && std::abs(source.y - b.y - b.h) < 1)
            attempt((source.y - p.y) / delta.y, false, false);
    }
    return result;
}
}
