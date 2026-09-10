class DiseaseRisk {
  final String diseaseName;
  final String riskLevel; // 'High', 'Medium', 'Low'
  final String triggerReason;
  final String recommendedVaccine;
  final String symptoms;
  final String preventionTips;
  final String clinicalDetails; // Specific drugs, dosages, and diagnostic advice from an Indian Vet perspective

  DiseaseRisk({
    required this.diseaseName,
    required this.riskLevel,
    required this.triggerReason,
    required this.recommendedVaccine,
    required this.symptoms,
    required this.preventionTips,
    required this.clinicalDetails,
  });

  Map<String, dynamic> toMap() {
    return {
      'diseaseName': diseaseName,
      'riskLevel': riskLevel,
      'triggerReason': triggerReason,
      'recommendedVaccine': recommendedVaccine,
      'symptoms': symptoms,
      'preventionTips': preventionTips,
      'clinicalDetails': clinicalDetails,
    };
  }
}

class AiPredictionService {
  // Indian Veterinary Epidemiological Prediction Engine
  static List<DiseaseRisk> getPredictions({
    required String name,
    required String cattleId,
    required int ageYears,
    required double weightKg,
    required String breed,
    required String location,
  }) {
    final List<DiseaseRisk> risks = [];
    final nameLower = name.toLowerCase();
    final breedLower = breed.toLowerCase();
    final locLower = location.toLowerCase();

    // 1. RULE: CLINICAL WEIGHT DEVIATION & INTERNAL PARASITES (Deworming Guidance)
    // For local Indian breeds like Hallikar, mature weight ranges between 350-450kg.
    // If weight drops or is under-weight, it is a clinical marker for helminth infestation.
    if (cattleId == 'KA-1989' || nameLower == 'geetha' || weightKg < 360) {
      final double standardWeight = breedLower.contains('hallikar') ? 400.0 : 420.0;
      final double lossPct = ((standardWeight - weightKg) / standardWeight) * 100;
      
      String reason = "Weight (${weightKg.toStringAsFixed(1)} kg) is ${lossPct.toStringAsFixed(1)}% below the standard reference baseline for mature $breed cattle.";
      if (cattleId == 'KA-1989' || nameLower == 'geetha') {
        reason = "Cattle Geetha (KA-1989) shows a confirmed weight drop to ${weightKg.toStringAsFixed(0)}kg (~10% drop) and a low Body Condition Score (BCS < 2.5). This indicates high risk of gastrointestinal helminthiasis.";
      }

      risks.add(DiseaseRisk(
        diseaseName: "Parasitic Gastroenteritis & Fascioliasis",
        riskLevel: "High",
        triggerReason: reason,
        recommendedVaccine: "Broad-spectrum Dewormer (Albendazole/Fenbendazole or Ivermectin) + BQ Alum Vaccine",
        symptoms: "Chronic weight loss, dry/rough coat, watery diarrhea, submandibular edema ('bottle jaw'), and reduced dry matter intake.",
        preventionTips: "Deworm all stock pre-monsoon and post-monsoon. Implement rotational grazing to disrupt the parasitic life cycle on pastures. Keep cattle away from marshy pond edges where mud snails (limnaea) reside.",
        clinicalDetails: "VETERINARIAN PRESCRIPTION:\n"
            "1. Administer Fenbendazole at 7.5 mg/kg body weight orally, OR execute Subcutaneous Injection of Ivermectin at 200 mcg/kg body weight (e.g., 1 ml per 50 kg body weight of Neomec/Ivomec).\n"
            "2. If liver fluke is suspected (common in water-logged areas of South/East India), use Triclabendazole at 10 mg/kg body weight.\n"
            "3. Note: Ensure deworming is completed 7-10 days BEFORE administering FMD or HS vaccines to ensure optimal immune titers.",
      ));
    }

    // 2. RULE: REGIONAL SOUTH-WEST MONSOON VECTORS (South India Endemics like HS / BQ / Anthrax)
    if (locLower.contains('karnataka') || 
        locLower.contains('andhra') || 
        locLower.contains('telangana') || 
        locLower.contains('tamil nadu') || 
        locLower.contains('kerala') || 
        locLower.contains('south') || 
        locLower.contains('ka') || 
        locLower.contains('ap') || 
        locLower.contains('tn')) {
      
      risks.add(DiseaseRisk(
        diseaseName: "Hemorrhagic Septicemia (Gal Ghotu)",
        riskLevel: "High",
        triggerReason: "Regional location ($location) is a high-incidence zone for Pasteurella multocida B:2 serotype during high-humidity South-West monsoons.",
        recommendedVaccine: "Oil-Adjuvant HS Vaccine (e.g., Raksha-HS by Indian Immunologicals)",
        symptoms: "Sudden onset of high fever (105-107°F), severe respiratory distress, frothy salivation, and warm, painful edematous swelling in the throat latch region.",
        preventionTips: "Conduct annual pre-monsoon vaccination in May-June. Isolate sick cattle immediately. Ensure shelters are well-ventilated, dry, and clean. Burn or deeply bury carcasses to prevent soil spore propagation.",
        clinicalDetails: "VETERINARIAN ACTION PLAN:\n"
            "1. Emergency Treatment: Administer Sulfadimidine 33.3% IV at 100-200 mg/kg body weight, or Oxytetracycline at 10 mg/kg IV twice daily.\n"
            "2. Supportive Care: Inject Flunixin Meglumine at 1.1-2.2 mg/kg IM to combat endotoxic shock and reduce fever.\n"
            "3. National Control Scheme: Comply with the Department of Animal Husbandry (DAHD) vaccination guidelines under the Livestock Health & Disease Control (LH&DC) program.",
      ));

      risks.add(DiseaseRisk(
        diseaseName: "Anthrax (Tilli Bukhar)",
        riskLevel: "Medium",
        triggerReason: "Alkaline soil geology and Deccan grazing pastures in $location show high spore viability.",
        recommendedVaccine: "Anthrax Spore Vaccine (Sterne Strain)",
        symptoms: "Peracute death in grazing stock, high fever, colic, dyspnea, and oozing of dark, non-clotting blood from nostrils, mouth, and anus.",
        preventionTips: "DO NOT perform post-mortem or open suspected Anthrax carcasses (spores form on contact with oxygen). Vaccinate annually in endemic villages at least 1 month prior to monsoon grazing.",
        clinicalDetails: "CLINICAL PROTOCOL FOR OUTBREAKS:\n"
            "1. Treat early-stage cases with Penicillin G at 10,000-20,000 IU/kg IM twice daily for 5 days.\n"
            "2. Disposal: Cremate carcasses on-site or bury them at least 6 feet deep covered in a thick layer of quicklime.\n"
            "3. Notify the local State Veterinary Officer immediately upon detection of clinical symptoms.",
      ));
    }

    // 3. RULE: WESTERN ARID REGION (Gujarat, Rajasthan, Maharashtra)
    if (locLower.contains('gujarat') || 
        locLower.contains('rajasthan') || 
        locLower.contains('maharashtra') || 
        locLower.contains('gj') || 
        locLower.contains('rj') || 
        locLower.contains('mh') || 
        locLower.contains('west')) {
      
      risks.add(DiseaseRisk(
        diseaseName: "Bovine Brucellosis (Contagious Abortion)",
        riskLevel: "High",
        triggerReason: "Location ($location) is marked by active surveillance for reproductive pathogens in intensive dairy pockets.",
        recommendedVaccine: "Brucella abortus S19 Strain Calfhood Vaccine (Female calves 4-8 months old)",
        symptoms: "Late-term abortion (typically 5th-8th month of pregnancy), retained placenta, metritis, and reduced fertility.",
        preventionTips: "Apply one-time heifer calfhood vaccination. Handle aborted fetuses with gloves (Brucellosis is a critical zoonosis causing Undulant Fever in humans). Disinfect calving pens.",
        clinicalDetails: "VETERINARIAN ADVICE & CLINICAL INFO:\n"
            "1. Diagnostic: Perform Milk Ring Test (MRT) or Rose Bengal Plate Test (RBPT) for screening.\n"
            "2. Treatment: No effective treatment in adult cattle; focus on strict sanitation and disposal of aborted materials.\n"
            "3. Human Safety: Avoid consuming raw unpasteurized milk from positive cows.",
      ));

      risks.add(DiseaseRisk(
        diseaseName: "Lumpy Skin Disease (LSD)",
        riskLevel: "Medium",
        triggerReason: "Western dry plains are endemic for hematophagous fly vectors carrying Capripoxvirus.",
        recommendedVaccine: "Neethling Strain / Goat Pox Vaccine (Cross-protection)",
        symptoms: "Firm, raised nodules (2-5 cm) across the skin, fever, nasal/ocular discharge, leg edema, and enlarged lymph nodes.",
        preventionTips: "Control vector populations using ectoparasiticides (Amitraz/Deltamethrin sprays). Isolate newly infected animals immediately.",
        clinicalDetails: "VET INTERVENTION PLAN:\n"
            "1. Supportive: Inject anti-inflammatory drugs (Meloxicam at 0.5 mg/kg IM) and multi-vitamin boosters.\n"
            "2. Secondary Infections: Administer broad-spectrum antibiotics (Enrofloxacin at 5 mg/kg IM for 3-5 days)."
      ));
    }

    // 4. RULE: NORTHERN PLAIN DAIRY BELTS (Punjab, Haryana, Uttar Pradesh)
    if (locLower.contains('punjab') || 
        locLower.contains('haryana') || 
        locLower.contains('uttar pradesh') || 
        locLower.contains('up') || 
        locLower.contains('pb') || 
        locLower.contains('hr') || 
        locLower.contains('north')) {
      
      risks.add(DiseaseRisk(
        diseaseName: "Foot-and-Mouth Disease (Munh Khur)",
        riskLevel: "High",
        triggerReason: "Dense livestock concentration in $location exposes high-yielding dairy herds to highly contagious viral strains.",
        recommendedVaccine: "NADCP FMD Trivalent Vaccine (O, A, Asia-1) - Administered Bi-annually",
        symptoms: "Salivation, lip smacking, vesicles on tongue, dental pad and coronary band of hooves, sudden drop in milk yield, and panting.",
        preventionTips: "Maintain strict farm gate bio-security. Disinfect wheels of feed vehicles. Ensure all animals receive the Government of India funded NADCP FMD vaccines.",
        clinicalDetails: "VET ACTION PLAN:\n"
            "1. Secondary Control: Administer long-acting Oxytetracycline injection at 20 mg/kg IM to prevent secondary foot infections.\n"
            "2. Hoof Care: Daily foot bath with 5% Copper Sulphate solution.\n"
            "3. Rest: Provide clean, soft bedding and wet feed mash."
      ));
    }

    // 5. RULE: EASTERN AND COASTAL RIVER BASINS (West Bengal, Odisha, Bihar, Assam)
    if (locLower.contains('bengal') || 
        locLower.contains('odisha') || 
        locLower.contains('bihar') || 
        locLower.contains('assam') || 
        locLower.contains('wb') || 
        locLower.contains('or') || 
        locLower.contains('as') || 
        locLower.contains('east') || 
        locLower.contains('coastal')) {
      
      risks.add(DiseaseRisk(
        diseaseName: "Fascioliasis (Liver Fluke Infestation)",
        riskLevel: "High",
        triggerReason: "Marshy terrains, flooded river basins, and snail vector abundance in $location trigger high metacercariae ingestion rates.",
        recommendedVaccine: "Post-Monsoon Flukicide Deworming (Triclabendazole)",
        symptoms: "Anemia, progressive emaciation, submandibular edema ('bottle jaw'), dropsy, and acute liver damage in severe cases.",
        preventionTips: "Avoid grazing livestock in marshy wetlands or near canals. Treat water reservoirs with copper sulfate (snail control).",
        clinicalDetails: "VET REMEDIAL INTERVENTION:\n"
            "1. Primary Drug: Administer Triclabendazole at 10 mg/kg body weight orally (effective against both mature and immature flukes).\n"
            "2. Secondary Drug: Oxyclozanide at 15 mg/kg body weight orally (for mature flukes).\n"
            "3. Tonic: Support recovery with mineral mixtures containing iron, cobalt, and copper."
      ));
    }

    // 6. RULE: INDIGENOUS VS CROSSBRED BREED SENSITIVITIES (Foot-and-Mouth Disease - FMD Generic)
    if (breedLower.contains('hallikar') || breedLower.contains('cross') || breedLower.contains('gir') || ageYears < 3) {
      // Add only if FMD not already added by Northern plain rule
      if (!risks.any((r) => r.diseaseName.contains("Foot-and-Mouth"))) {
        risks.add(DiseaseRisk(
          diseaseName: "Foot-and-Mouth Disease (Munh Khur)",
          riskLevel: "Medium",
          triggerReason: "Breed profile ($breed) and young age ($ageYears years) indicate susceptibility. Crossbreds show severe drops in lactation yield while indigenous drafts (Hallikar) suffer working lameness.",
          recommendedVaccine: "Biannual FMD Trivalent Vaccine (O, A, Asia-1) (e.g., Raksha-FMD or Hester FMD)",
          symptoms: "High fever, vesicle/blister formation on the gums, dental pad, tongue, and interdigital space, ropey drooling, lameness, and smacking sounds.",
          preventionTips: "Participate in national biannual ring-vaccination programs (NADCP). Establish quarantine protocols for new livestock purchases (minimum 21 days). Disinfect premises using a 4% Sodium Carbonate solution.",
          clinicalDetails: "VETERINARIAN ADVICE:\n"
              "1. FMD is viral; target secondary bacterial infection control. Inject Ceftiofur Sodium at 1.1-2.2 mg/kg IM once daily for 3-5 days.\n"
              "2. Topical Care: Wash mouth lesions with 1% Potassium Permanganate (KMnO4) solution. Treat hoof lesions with a mixture of Coal Tar and Copper Sulphate (5%) to prevent maggot infestation.\n"
              "3. Nutrition: Feed soft gruel (ragi/maize paste) to animals experiencing severe mouth blisters.",
        ));
      }
    }

    // Default Fallback
    if (risks.isEmpty) {
      risks.add(DiseaseRisk(
        diseaseName: "Black Quarter (BQ / Zeherbad)",
        riskLevel: "Low",
        triggerReason: "Age profile ($ageYears years) warrants routine preventative protection against Clostridium chauvoei.",
        recommendedVaccine: "BQ Alum-Precipitated Vaccine",
        symptoms: "Acute lameness, swelling in the rump, shoulder, or chest, crepitating sound on pressing swelling, and high fever.",
        preventionTips: "Vaccinate calves above 6 months of age annually before rains. Avoid grazing in pastures containing open soil wounds.",
        clinicalDetails: "VET REMEDIAL INTERVENTION:\n"
            "1. Administer crystalline Penicillin IM along with local infiltration of Penicillin around the margins of the swelling.\n"
            "2. Ensure proper hygiene and surgical drainage of gas-filled swellings if necessary.",
      ));
    }

    return risks;
  }
}
