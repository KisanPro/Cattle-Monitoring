from typing import Dict, Any, List

class VeterinaryRules:
    """
    Expert Veterinary Knowledge-Base mapping multivariable changes
    (Milk Drop + Weight Drop + Vaccine Timing) into clinical risk assessments.
    """

    @staticmethod
    def evaluate_clinical_implications(features: Dict[str, Any], cattle_meta: Dict[str, Any]) -> Dict[str, Any]:
        delta_milk_pct = features.get("delta_milk_pct_7d", 0.0)
        delta_milk_peak = features.get("delta_milk_from_peak", 0.0)
        delta_weight_pct = features.get("delta_weight_pct_7d", 0.0)
        delta_weight_peak = features.get("delta_weight_from_peak", 0.0)
        vaccine_status = features.get("vaccine_status", "Up to Date")
        breed = cattle_meta.get("breed", "HF")
        name = cattle_meta.get("name", "Cattle")

        hypotheses = []
        recommendations = []
        observations = []

        # -----------------------------------------------------------------
        # Pattern 1: Simultaneous Milk Drop + Weight Loss (The Geetha KA-1989 pattern)
        # -----------------------------------------------------------------
        if (delta_milk_pct <= -15.0 or delta_milk_peak <= -25.0) and (delta_weight_pct <= -1.5 or delta_weight_peak <= -2.5):
            observations.append(
                f"A continuous decrease in milk production ({features['peak_milk_historical']} L → {features['current_milk']} L) "
                f"and body weight ({features['peak_weight_historical']} kg → {features['current_weight']} kg) has been detected."
            )
            observations.append(
                "The combined multi-parameter changes indicate that the cattle requires immediate increased health monitoring."
            )
            hypotheses.append("Subclinical Mastitis / Chronic Infection")
            hypotheses.append("Negative Energy Balance (Subclinical Ketosis)")
            hypotheses.append("Gastrointestinal Parasitism / Helminthiasis")
            hypotheses.append("Nutritional Energy/Protein Deprivation")

            recommendations.append("Check feeding behaviour, dry matter intake, and physical rumination condition.")
            recommendations.append("Perform California Mastitis Test (CMT) on all 4 quarters to rule out intramammary infection.")
            recommendations.append("Review vaccination booster schedule and administer pre-monsoon broad-spectrum deworming if overdue.")
            recommendations.append("Veterinary clinical examination should be considered immediately if the abnormal trend continues.")

        # -----------------------------------------------------------------
        # Pattern 2: Acute Milk Drop with Stable Weight
        # -----------------------------------------------------------------
        elif delta_milk_pct <= -20.0 and delta_weight_pct > -1.5:
            observations.append(
                f"Acute sudden drop in daily milk yield ({delta_milk_pct:.1f}%) with relatively preserved body mass."
            )
            hypotheses.append("Acute Mastitis (Udder inflammation/heat)")
            hypotheses.append("Acute Systemic Stress / Heat Stress")
            hypotheses.append("Early Febrile Episode / Transient Indigestion")

            recommendations.append("Check rectal temperature (normal range: 101.5°F - 102.5°F).")
            recommendations.append("Inspect udder for swelling, redness, hardness, or clotty milk.")
            recommendations.append("Ensure ad-lib clean drinking water and electrolyte supplementation.")

        # -----------------------------------------------------------------
        # Pattern 3: Progressive Weight Loss with Sub-Optimal Milk
        # -----------------------------------------------------------------
        elif delta_weight_pct <= -3.0:
            observations.append(
                f"Significant loss of body condition score and mass ({delta_weight_pct:.1f}% drop)."
            )
            hypotheses.append("Helminthiasis (Fascioliasis / Amphistomiasis)")
            hypotheses.append("Nutritional Malabsorption / Chronic Acidosis")

            recommendations.append("Administer Fenbendazole or Ivermectin broad-spectrum dewormer.")
            recommendations.append("Supplement high-energy bypass fat and mineral mixture (50g daily).")

        # -----------------------------------------------------------------
        # Pattern 4: Normal Healthy Parameters
        # -----------------------------------------------------------------
        else:
            observations.append(
                f"Milk production ({features['current_milk']} L) and body weight ({features['current_weight']} kg) "
                f"are within normal biological tolerance ranges for {breed} breed."
            )
            recommendations.append("Continue standard feeding, watering, and daily monitoring protocols.")

        # Add vaccination-specific observations
        if vaccine_status == "Overdue":
            observations.append(f"Crucial vaccination booster is OVERDUE ({', '.join(features.get('overdue_vaccines', []))}).")
            recommendations.append("Schedule urgent veterinary visit for mandatory vaccination boosters.")
        elif vaccine_status == "Due Soon":
            observations.append(f"Vaccination booster is due soon ({', '.join(features.get('due_soon_vaccines', []))}).")
            recommendations.append("Prepare vaccines and verify cold-chain storage for upcoming booster window.")

        return {
            "observations": observations,
            "hypotheses": hypotheses,
            "recommendations": recommendations
        }
