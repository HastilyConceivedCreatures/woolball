pragma solidity >=0.8.28;

import "./interfaces/INamePricing.sol";

contract NamePricing is INamePricing {
    /**
     * @notice Calculates the cost of registering a name for a specified duration in weeks.
     * @dev The cost is based on the length of the name and applies a discount for every 52 weeks.
     *      - Names with 5 or more characters cost 25 cents per week.
     *      - Names with 4 characters cost 250 cents per week.
     *      - Names with 3 or fewer characters cost 2500 cents per week.
     *      - For every 52 weeks booked, only 40 weeks are charged, giving a yearly discount.
     * @param name The name to be registered.
     * @param duration_in_weeks The duration of registration in weeks.
     * @return totalCost The total cost of the registration in cents.
     */
    function cost(
        string calldata name,
        uint32 duration_in_weeks
    ) external pure override returns (uint256) {
        // Determine the length of the name
        uint256 nameLength = bytes(name).length;
        
        // Initialize the price per week in cents
        uint256 pricePerWeek;

        // Disallow short names in this pricing contract
        require(nameLength > 3, "Woolball: names must be at least 3 characters.");


        // Set price based on name length in cents
        if (nameLength >= 5) {
            pricePerWeek = 25;       // 25 cents per week for names with 5+ characters
        } else if (nameLength == 4) {
            pricePerWeek = 250;      // 250 cents per week for names with 4 characters
        } else {
            pricePerWeek = 2500;     // 2500 cents per week for names with 3 or fewer characters
        }

        // Calculate the total weeks that need to be paid for (apply a discount for 52-week periods)
        uint256 chargeableWeeks = (duration_in_weeks / 52) * 40 + (duration_in_weeks % 52);

        // Calculate total cost in cents
        uint256 totalCost = pricePerWeek * chargeableWeeks;

        return totalCost;
    }
}
