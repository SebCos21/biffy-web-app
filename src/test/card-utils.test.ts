import { describe, expect, it } from "vitest";
import {
  detectCardBrand,
  formatCardNumber,
  formatExpiry,
  isExpiryValid,
  luhnCheck,
  getBrandLabel,
} from "@/lib/card-utils";

describe("card-utils validation and formatting", () => {
  it("detects card brands correctly", () => {
    expect(detectCardBrand("4242424242424242")).toBe("visa");
    expect(detectCardBrand("5555555555554444")).toBe("mastercard");
    expect(detectCardBrand("378282246310005")).toBe("amex");
    expect(detectCardBrand("9999999999999999")).toBe("other");
  });

  it("formats card numbers with spacing", () => {
    expect(formatCardNumber("4242424242424242")).toBe("4242 4242 4242 4242");
    expect(formatCardNumber("4242")).toBe("4242");
  });

  it("formats and validates expiration dates", () => {
    expect(formatExpiry("1228")).toBe("12/28");
    expect(isExpiryValid("12/28")).toBe(true);
    expect(isExpiryValid("13/28")).toBe(false);
    expect(isExpiryValid("01/20")).toBe(false); // Past date
  });

  it("validates Luhn algorithm", () => {
    expect(luhnCheck("4242424242424242")).toBe(true);
    expect(luhnCheck("4242424242424243")).toBe(false); // Invalid checksum
  });

  it("returns human-readable brand labels", () => {
    expect(getBrandLabel("visa")).toBe("Visa");
    expect(getBrandLabel("mastercard")).toBe("Mastercard");
    expect(getBrandLabel("amex")).toBe("American Express");
  });
});
