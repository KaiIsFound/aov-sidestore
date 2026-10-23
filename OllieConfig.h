#pragma once

#include <atomic>
#include <map>

// UI writes and game callbacks may run on different threads.
struct CheatConfig {
    std::atomic<bool> espMaster{true};
    std::atomic<bool> espBox{true};
    std::atomic<bool> espLine{true};
    std::atomic<bool> espHealth{true};
    std::atomic<bool> espSkillCD{true};
    std::atomic<bool> espMinimap{true};
    std::atomic<bool> espJungleTimer{true};
    std::atomic<bool> hackMap{true};
    std::atomic<float> camHeightRate{1.65f};
    std::atomic<bool> autoSmite{true};
    std::atomic<bool> aimElsu{true};
    std::atomic<bool> skinMaster{true};
    std::map<int, int> skinMap = {
        {150, 11}, {167, 12}, {111, 15}, {196, 8}, {520, 7}
    };
    std::atomic<bool> streamProof{true};
};

extern CheatConfig cfg;
