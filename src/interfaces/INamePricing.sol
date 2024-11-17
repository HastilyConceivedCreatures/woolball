pragma solidity >=0.8.28;

interface INamePricing {
    // NONE = uninitiated
    // HUMAN - a human name, e.g., 'neiman#'
    // ARTIFICIAL - a nonhuman name, created by a human, e.g., 'woolball##'
    // SUBNAME - 'car.neiman#'
    enum NameType {
        NONE,
        HUMAN,
        SUBNAME,
        ARTIFICIAL
    }

    function cost(
        string calldata name,
        uint32 duration_in_days
    ) external returns (uint256);
}
