# Body Composition & Fat Mathematical Estimation Documentation

This document explains the mathematical formulas, inputs, boundary validations, and physiological categories used by **Fomo IF** to estimate body composition.

> [!WARNING]
> All calculation outputs provided by this application are mathematical estimates based on population averages. They are intended for educational and progress-tracking purposes only and do **not** constitute clinical assessments or medical diagnoses.

---

## 1. Body Fat Percentage (U.S. Navy Formula)

The U.S. Navy Body Fat Formula is the most widely validated circumference-based body fat estimation method. It computes body fat percentage based on height and body circumferences using logarithmic ratios.

### Male Formula
\[\text{BF}_{\text{male}}\% = 495 / \left(1.0324 - 0.19077 \times \log_{10}(\text{waist}_{\text{cm}} - \text{neck}_{\text{cm}}) + 0.15456 \times \log_{10}(\text{height}_{\text{cm}})\right) - 450\]

*Note: The difference between waist and neck circumference (\(\text{waist} - \text{neck}\)) represents abdominal fat distribution.*

### Female Formula
\[\text{BF}_{\text{female}}\% = 495 / \left(1.29579 - 0.35004 \times \log_{10}(\text{waist}_{\text{cm}} + \text{hip}_{\text{cm}} - \text{neck}_{\text{cm}}) + 0.22100 \times \log_{10}(\text{height}_{\text{cm}})\right) - 450\]

*Note: Includes hip circumference to account for gluteofemoral fat distribution in women.*

---

## 2. Core Anthropometric Metrics

### Body Mass Index (BMI)
A simple metric of body mass normalized to height, used to categorize weight status:
\[\text{BMI} = \frac{\text{weight}_{\text{kg}}}{\left(\text{height}_{\text{m}}\right)^2}\]

### Lean Body Mass (LBM)
The mass of everything in the body except fat (bones, organs, muscles, water):
\[\text{LBM}_{\text{kg}} = \text{weight}_{\text{kg}} \times \left(1 - \frac{\text{BF}\%}{100}\right)\]

### Fat Mass (FM)
The absolute weight of adipose tissue in the body:
\[\text{FM}_{\text{kg}} = \text{weight}_{\text{kg}} - \text{LBM}_{\text{kg}}\]

---

## 3. Daily Energy Requirements

### Basal Metabolic Rate (BMR)
The energy expended by the body at rest. Calculated using the **Mifflin-St Jeor Equation** (widely accepted as the most accurate formula for modern populations):

*   **Male**: \(\text{BMR} = 10 \times \text{weight}_{\text{kg}} + 6.25 \times \text{height}_{\text{cm}} - 5 \times \text{age}_{\text{years}} + 5\)
*   **Female**: \(\text{BMR} = 10 \times \text{weight}_{\text{kg}} + 6.25 \times \text{height}_{\text{cm}} - 5 \times \text{age}_{\text{years}} - 161\)

### Total Daily Energy Expenditure (TDEE)
The estimated number of calories burned in a day, applying activity multipliers to BMR. Fomo IF assumes a **Moderate Activity Multiplier** (\(1.375 \times \text{BMR}\)) representing light-to-moderate exercise 1–3 days a week.

---

## 4. Health Ratios & Indices

### Waist-to-Height Ratio (WHtR)
A powerful cardiovascular and metabolic risk marker:
\[\text{WHtR} = \frac{\text{waist}_{\text{cm}}}{\text{height}_{\text{cm}}}\]

*   **WHtR < 0.5**: Healthy abdominal fat distribution.
*   **WHtR ≥ 0.5**: Increased risk of visceral fat accumulation and cardiovascular complications.

### Ideal Body Weight (Devine Formula)
Estimates healthy weight based on height:
*   **Male**: \(50.0\text{ kg} + 2.3\text{ kg} \times (\text{height}_{\text{inches}} - 60)\)
*   **Female**: \(45.5\text{ kg} + 2.3\text{ kg} \times (\text{height}_{\text{inches}} - 60)\)

---

## 5. Body Fat Categories

Circumference results are categorized based on guidelines from the **American Council on Exercise (ACE)**:

| Category | Male Range | Female Range |
|---|---|---|
| **Essential Fat** | \(3 - 5\%\) | \(10 - 13\%\) |
| **Athletes** | \(6 - 13\%\) | \(14 - 20\%\) |
| **Fitness** | \(14 - 17\%\) | \(21 - 24\%\) |
| **Average** | \(18 - 24\%\) | \(25 - 31\%\) |
| **Obese** | \(\geq 25\%\) | \(\geq 32\%\) |

---

## 6. Input Boundary Validations
To prevent mathematically invalid inputs (such as taking logs of negative numbers or creating physical anomalies), the application enforces these rules:
1. **Weight**: Must be between 30 kg and 300 kg.
2. **Height**: Must be between 100 cm and 250 cm.
3. **Waist > Neck**: Abdominal circumference must exceed neck circumference.
4. **Waist + Hip > Neck (Female)**: Combined waist and hip circumferences must exceed neck circumference.

---

## 7. References
1. Hodgdon, J. A., & Beckett, M. B. (1984). *Prediction of body fat for military personnel*. Naval Health Research Center.
2. Mifflin, M. D., St Jeor, S. T., et al. (1990). *A new predictive equation for resting energy expenditure in healthy individuals*. The American Journal of Clinical Nutrition.
3. Devine, B. J. (1974). *Gentamicin therapy*. Drug Intelligence and Clinical Pharmacy.
