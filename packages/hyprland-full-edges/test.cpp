// SPDX-License-Identifier: MIT
#include "geometry.hpp"
#include <cassert>
using namespace FullEdges;
int main() {
    Box laptop{-1920, 120, 1920, 1200}, bottom{0, 0, 2560, 1440}, top{320, -1080, 1920, 1080};
    // The extreme upper corners of the lower screen have no geometric overlap.
    auto p = cross(bottom, {top, laptop}, {2500, 1}, {0, -5});
    assert(p && p->x > 2190 && p->x < 2240 && p->y == -2);
    p = cross(bottom, {top, laptop}, {20, 1}, {0, -5});
    assert(p && p->x >= 320 && p->x < 340);
    p = cross(top, {bottom, laptop}, {1280, -1}, {0, 5});
    assert(p && p->x == 1280 && p->y == 2);
    p = cross(laptop, {bottom, top}, {-1, 720}, {5, 0});
    assert(p && p->x == 2 && p->y == 720);
    p = cross(bottom, {laptop, top}, {1, 1420}, {-5, 0});
    assert(p && p->x == -2 && p->y > 1300 && p->y < 1320);
    assert(!cross(bottom, {top, laptop}, {2559, 800}, {5, 0}));
    assert(!cross(bottom, {top, laptop}, {1000, 800}, {1, 0}));
    assert(!cross(bottom, {}, {1, 10}, {-5, 0}));
    // Diagonal-only and physically separated displays are not neighbours.
    assert(!cross(bottom, {{2560, -1080, 1920, 1080}}, {2559, 1}, {5, -5}));
    assert(!cross(bottom, {{3000, 0, 1920, 1080}}, {2559, 800}, {5, 0}));
}
