from typing import Dict, Any
from .feature_extractor import FeatureExtractor
from .risk_classifier import RiskClassifier
from .veterinary_rules import VeterinaryRules

class AlertGenerator:
    """
    Synthesizes features, risk scores, and veterinary observations
    into structured early-warning alerts for farmers and vets.
    """

    @staticmethod
    def generate_assessment_report(
        farm_info: Dict[str, Any],
        cattle_info: Dict[str, Any],
        features: Dict[str, Any]
    ) -> Dict[str, Any]:
        risk_level, health_score = RiskClassifier.classify_health_risk(features)
        vet_eval = VeterinaryRules.evaluate_clinical_implications(features, cattle_info)

        # Build Detected Changes Dictionary matching the user's exact format
        peak_milk = features.get("peak_milk_historical", features["current_milk"])
        cur_milk = features["current_milk"]
        milk_change_str = f"{peak_milk:.1f} L → {cur_milk:.1f} L" if peak_milk != cur_milk else f"{cur_milk:.1f} L (Stable)"

        peak_weight = features.get("peak_weight_historical", features["current_weight"])
        cur_weight = features["current_weight"]
        weight_change_str = f"{peak_weight:.0f} kg → {cur_weight:.0f} kg" if peak_weight != cur_weight else f"{cur_weight:.0f} kg (Stable)"

        vaccine_status_str = features.get("vaccine_status", "Up to Date")

        detected_changes = {
            "Milk Production": milk_change_str,
            "Weight": weight_change_str,
            "Vaccination": vaccine_status_str,
            "Raw": {
                "milk_peak": peak_milk,
                "milk_current": cur_milk,
                "weight_peak": peak_weight,
                "weight_current": cur_weight,
                "delta_milk_pct": features.get("delta_milk_pct_7d", 0.0),
                "delta_weight_pct": features.get("delta_weight_pct_7d", 0.0)
            }
        }

        ai_obs_text = "\n\n".join(vet_eval["observations"])
        rec_action_text = "\n".join([f"• {r}" for r in vet_eval["recommendations"]])

        title = f"CATTLE HEALTH ALERT - {risk_level}" if risk_level != "NORMAL" else "CATTLE HEALTH STATUS - NORMAL"

        return {
            "farm_id": farm_info.get("farm_id", "Unknown_Farm"),
            "farmer_name": farm_info.get("farmer_name", "Farmer"),
            "cattle_id": cattle_info.get("cattle_id", "KA-1989"),
            "cattle_name": cattle_info.get("name", "Geetha"),
            "breed": cattle_info.get("breed", "HF"),
            "risk_level": risk_level,
            "health_score": health_score,
            "alert_title": title,
            "detected_changes": detected_changes,
            "ai_observation": ai_obs_text,
            "recommended_action": rec_action_text,
            "possible_reasons": vet_eval["hypotheses"],
            "disclaimer": "The AI system is identifying a health risk, not providing a definitive veterinary diagnosis. Consult a licensed veterinarian for medical prescription."
        }
