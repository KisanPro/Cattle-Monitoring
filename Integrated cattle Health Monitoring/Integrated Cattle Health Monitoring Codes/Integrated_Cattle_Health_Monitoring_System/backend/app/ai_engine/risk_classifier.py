from typing import Dict, Any, Tuple

class RiskClassifier:
    """
    Multivariable AI Health & Risk Classification Engine.
    Combines feature weights, statistical thresholding, and risk matrices.
    """

    @staticmethod
    def classify_health_risk(features: Dict[str, Any]) -> Tuple[str, float]:
        """
        Returns (risk_level, health_score)
        health_score: 0.0 (Dead/Extreme critical) to 100.0 (Optimum health)
        risk_level: NORMAL, WARNING, HIGH RISK, CRITICAL
        """
        score = 100.0

        delta_milk_pct = features.get("delta_milk_pct_7d", 0.0)
        delta_milk_peak = features.get("delta_milk_from_peak", 0.0)
        delta_weight_pct = features.get("delta_weight_pct_7d", 0.0)
        delta_weight_peak = features.get("delta_weight_from_peak", 0.0)
        vaccine_status = features.get("vaccine_status", "Up to Date")

        # -------------------------------------------------------------
        # 1. Milk Degradation Penalty
        # -------------------------------------------------------------
        effective_milk_drop = min(delta_milk_pct, delta_milk_peak)
        if effective_milk_drop < 0:
            drop_abs = abs(effective_milk_drop)
            if drop_abs > 30.0:
                score -= 35.0
            elif drop_abs > 20.0:
                score -= 25.0
            elif drop_abs > 10.0:
                score -= 15.0
            elif drop_abs > 5.0:
                score -= 5.0

        # -------------------------------------------------------------
        # 2. Weight Loss Penalty
        # -------------------------------------------------------------
        effective_weight_drop = min(delta_weight_pct, delta_weight_peak)
        if effective_weight_drop < 0:
            w_drop_abs = abs(effective_weight_drop)
            if w_drop_abs > 5.0: # >5% weight loss is severe in cattle
                score -= 35.0
            elif w_drop_abs > 2.5: # >2.5% is clinically significant
                score -= 22.0
            elif w_drop_abs > 1.0:
                score -= 10.0

        # -------------------------------------------------------------
        # 3. Multivariable Synergistic Penalty (Compounded Risk)
        # -------------------------------------------------------------
        # If BOTH milk and weight are dropping concurrently, it represents systemic illness
        if effective_milk_drop <= -15.0 and effective_weight_drop <= -2.0:
            score -= 15.0 # Multiplier penalty

        # -------------------------------------------------------------
        # 4. Vaccination Vulnerability Penalty
        # -------------------------------------------------------------
        if vaccine_status == "Overdue":
            score -= 15.0
        elif vaccine_status == "Due Soon":
            score -= 5.0

        # Clamp score to [0, 100]
        health_score = max(0.0, min(100.0, score))

        # -------------------------------------------------------------
        # 5. Risk Category Mapping
        # -------------------------------------------------------------
        if health_score >= 80.0:
            risk_level = "NORMAL"
        elif health_score >= 65.0:
            risk_level = "WARNING"
        elif health_score >= 40.0:
            risk_level = "HIGH RISK"
        else:
            risk_level = "CRITICAL"

        # Explicit override rule for severe multi-variable decline
        if (effective_milk_drop <= -25.0 and effective_weight_drop <= -2.5) and risk_level not in ["HIGH RISK", "CRITICAL"]:
            risk_level = "HIGH RISK"

        return risk_level, round(health_score, 1)
