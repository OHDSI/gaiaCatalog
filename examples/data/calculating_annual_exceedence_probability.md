The **95th percentile rainfall event** represents a high-magnitude precipitation value that is **exceeded only 5% of the time** (i.e., 95% of observed rainfall values are below it). It is commonly used in **hydrology**, **urban drainage design**, and **climate risk analysis** to assess extreme rainfall events.

---

### **Methods to Calculate the 95th Percentile Rainfall Event**
There are two primary approaches:

#### **1. Empirical (Non-Parametric) Method**  
**Use this when you have observed rainfall data.**  
**Steps:**  
1. **Collect rainfall data** (e.g., daily/annual maximum rainfall over N years).  
2. **Sort the data in ascending order.**  
3. **Compute the rank (position) of the 95th percentile:**  
   \[
   k = 0.95 \times N
   \]  
   - If \( k \) is an integer, the 95th percentile is the average of the \( k \)-th and \( (k+1) \)-th values.  
   - If \( k \) is not an integer, round up to the next whole number and take that value.  

**Example:**  
- Suppose you have **100 daily rainfall values (sorted)**.  
- \( k = 0.95 \times 100 = 95 \)  
- The 95th percentile is the **95th value** in the ordered dataset.  

---

#### **2. Statistical (Parametric) Method**  
**Use this when fitting a probability distribution (e.g., Gamma, Log-Normal, Gumbel).**  
**Steps:**  
1. **Fit rainfall data to a probability distribution** (e.g., Gamma distribution is common for rainfall).  
2. **Calculate the 95th percentile using the inverse CDF (quantile function).**  

**For Gamma Distribution:**  
\[
P(X \leq x) = F(x; \alpha, \beta)
\]  
where:  
- \( \alpha \) = shape parameter  
- \( \beta \) = scale parameter  
- The 95th percentile \( x_{0.95} \) is found using statistical software (e.g., Python’s `scipy.stats.gamma.ppf(0.95, alpha, scale=beta)`).  

**Example:**  
- If \( \alpha = 2 \), \( \beta = 10 \):  
  \[
  x_{0.95} \approx 31.4 \, \text{mm} \quad (\text{from Gamma tables or software})
  \]  
  → Rainfall **exceeds 31.4 mm only 5% of the time**.  

---

### **Key Considerations**  
- **Data Length Matters:** ≥30 years of data is ideal for robust estimates.  
- **Temporal Scale:** The 95th percentile can be calculated for **daily, hourly, or annual max rainfall**, depending on the application.  
- **Climate Change Adjustments:** In non-stationary climates, percentile thresholds may shift over time.  

Would you like help with a specific dataset or code implementation (e.g., Python/R)?
