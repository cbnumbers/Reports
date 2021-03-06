## Part 1 of HPHI Monthly Script

## Read in data & select needed columns

HPHI_Policy_Data <- read_csv("HPHI_Raw_Data_March.csv")
ITD_Claims_Data <- read_csv("ITD_Claims_March.csv")
ITD_Premiums_Data <- read_csv("ITD_Premiums_March.csv")

ITD_Claims_Data2 <- select(ITD_Claims_Data, PPOLICY, CLAM0701)
ITD_Premiums_Data2 <- select(ITD_Premiums_Data, PPOLICY, PHPAMT101)

## Filter out duplicates

HPHI_Policy_Data2 <- HPHI_Policy_Data %>%
  group_by(PPOLICY, PCOMPANY, PBLOCK, PRIDER, PSTATUS, PFORM, PPLAN, PISSUEDT, PISSUEST, PSNO13, PSCD09, AGCD01, AGENTNO, AGNAMEF, 
           AGNAMEL, AGTOPNAMEL) %>%
  count() 

HPHI_Policy_Data3 <- HPHI_Policy_Data2 %>%
  group_by(PPOLICY) %>%
  mutate(rank = min_rank(desc(AGCD01))) %>%
  filter(rank == 1) %>%
  mutate(rank2 = min_rank(AGENTNO)) %>%
  filter(rank2 == 1)

## Join in claims and premiums, create date columns, fix agent names, and select needed columns

HPHI_Policy_Data3$PISSUEDT <- ymd(HPHI_Policy_Data3$PISSUEDT)

HPHI_Policy_Data3$AGTOPNAMEL <- sub("BENEFITS TECH DIVISION 4", "BENEFITS TECH DIVISION", HPHI_Policy_Data3$AGTOPNAMEL)
HPHI_Policy_Data3$AGTOPNAMEL <- sub("MATTHEW MCKINNEY LLC-2", "MCKINNEY", HPHI_Policy_Data3$AGTOPNAMEL)

HPHI_Full_Data <- HPHI_Policy_Data3 %>%
  left_join(ITD_Premiums_Data2, by = "PPOLICY") %>%
  left_join(ITD_Claims_Data2, by = "PPOLICY") %>%
  mutate(Iss_Year = year(PISSUEDT)) %>%
  select(-PRIDER, -n, -rank, -rank2) %>%
  mutate(PHPAMT101 = if_else(is.na(PHPAMT101), 0, PHPAMT101), CLAM0701 = if_else(is.na(CLAM0701), 0, CLAM0701),
         LR = round((CLAM0701 / PHPAMT101) * 100), digits = 0)

HPHI_Full_Data2 <- HPHI_Full_Data %>%
  select(-digits) %>%
  mutate(Writing_Agent = paste(AGNAMEF, AGNAMEL, sep = ", "), Prod_Type = str_sub(PPLAN, 1, 2)) %>%
  mutate(LR = if_else(is.nan(LR), 0, LR), Product_Type = if_else(Prod_Type == "FH", "FC", "HPHI"))

## Summary Tables by various variables

Total_premiums <- dollar_format()(sum(HPHI_Full_Data2$PHPAMT101))
Total_claims <- dollar_format()(sum(HPHI_Full_Data2$CLAM0701))
Total_count <- nrow(HPHI_Full_Data2)
Total_LR <- Total_claims / Total_premiums
Overall_LR <- round(Total_LR, 2)

LR_By_Issue_State <- HPHI_Full_Data2 %>%
  group_by(PISSUEST) %>%
  summarise(Premiums_Sum = sum(PHPAMT101), Claims_Sum = sum(CLAM0701), Policy_Count = n()) %>%
  mutate(LR = round((Claims_Sum / Premiums_Sum * 100), digits = 0)) %>%
  filter(Premiums_Sum > 100000)

LR_By_Agent <- HPHI_Full_Data2 %>%
  group_by(Writing_Agent) %>%
  summarise(Premiums_Sum = sum(PHPAMT101), Claims_Sum = sum(CLAM0701), Policy_Count = n()) %>%
  mutate(LR = round((Claims_Sum / Premiums_Sum * 100), digits = 0))

LR_By_Agent_Top_Twenty <- LR_By_Agent %>%
  arrange(desc(Policy_Count)) %>%
  head(n = 20)

LR_By_Issue_Year <- HPHI_Full_Data2 %>%
  group_by(Iss_Year) %>%
  summarise(Premiums_Sum = sum(PHPAMT101), Claims_Sum = sum(CLAM0701), Policy_Count = n()) %>%
  mutate(LR = round((Claims_Sum / Premiums_Sum * 100), digits = 0))

LR_By_Top_Agent <- HPHI_Full_Data2 %>%
  group_by(AGTOPNAMEL) %>%
  summarise(Premiums_Sum = sum(PHPAMT101), Claims_Sum = sum(CLAM0701), Policy_Count = n()) %>%
  mutate(LR = round((Claims_Sum / Premiums_Sum * 100), digits = 0)) %>%
  filter(Premiums_Sum > 1000, LR > 0, AGTOPNAMEL != "NA")

LR_By_Gender <- HPHI_Full_Data2 %>%
  group_by(PSCD09) %>%
  summarise(Premiums_Sum = sum(PHPAMT101), Claims_Sum = sum(CLAM0701), Policy_Count = n()) %>%
  mutate(LR = round((Claims_Sum / Premiums_Sum * 100), digits = 0)) %>%
  filter(PSCD09 != "NA")

LR_By_Issue_Age <- HPHI_Full_Data2 %>%
  group_by(PSNO13) %>%
  summarise(Premiums_Sum = sum(PHPAMT101), Claims_Sum = sum(CLAM0701), Policy_Count = n()) %>%
  mutate(LR = round((Claims_Sum / Premiums_Sum * 100), digits = 0)) %>%
  filter(PSNO13 != "NA", PSNO13 > 17, Policy_Count > 20)

LR_By_Issue_Age_Gender <- HPHI_Full_Data2 %>%
  group_by(PSNO13, PSCD09) %>%
  summarise(Premiums_Sum = sum(PHPAMT101), Claims_Sum = sum(CLAM0701), Policy_Count = n()) %>%
  mutate(LR = round((Claims_Sum / Premiums_Sum * 100), digits = 0)) %>%
  filter(PSNO13 != "NA", PSNO13 > 17, PSCD09 != "NA")

LR_By_Product <- HPHI_Full_Data2 %>%
  group_by(Product_Type) %>%
  summarise(Premiums_Sum = sum(PHPAMT101), Claims_Sum = sum(CLAM0701), Policy_Count = n()) %>%
  mutate(LR = round((Claims_Sum / Premiums_Sum * 100), digits = 0))

LR_By_Product_Gender <- HPHI_Full_Data2 %>%
  group_by(Product_Type, PSCD09) %>%
  summarise(Premiums_Sum = sum(PHPAMT101), Claims_Sum = sum(CLAM0701), Policy_Count = n()) %>%
  mutate(LR = round((Claims_Sum / Premiums_Sum * 100), digits = 0)) %>%
  filter(PSCD09 != "NA") %>%
  mutate(Prems_Per_Pol = round(Premiums_Sum / Policy_Count), Claims_Per_Pol = round(Claims_Sum / Policy_Count))

LR_By_Product_Age <- HPHI_Full_Data2 %>%
  group_by(Product_Type, PSNO13) %>%
  summarise(Premiums_Sum = sum(PHPAMT101), Claims_Sum = sum(CLAM0701), Policy_Count = n()) %>%
  mutate(LR = round((Claims_Sum / Premiums_Sum * 100), digits = 0)) %>%
  filter(PSNO13 != "NA", PSNO13 > 17, Product_Type != "NA")

LR_By_Product_Age_Gender <- HPHI_Full_Data2 %>%
  group_by(PSCD09, Product_Type, PSNO13) %>%
  summarise(Premiums_Sum = sum(PHPAMT101), Claims_Sum = sum(CLAM0701), Policy_Count = n()) %>%
  mutate(LR = round((Claims_Sum / Premiums_Sum * 100), digits = 0)) %>%
  filter(PSNO13 != "NA", PSNO13 > 17, Product_Type != "NA", PSCD09 != "NA") %>%
  mutate(Prems_Per_Pol = round(Premiums_Sum / Policy_Count), Claims_Per_Pol = round(Claims_Sum / Policy_Count))

## Plots

ggplot(LR_By_Issue_Year, aes(x = Iss_Year, y = LR)) +
  geom_line(col = "blue") +
  geom_point(aes(size = Premiums_Sum), col = "blue", alpha = .5) +
  scale_x_continuous(breaks = c(2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017)) +
  labs(title = "ITD LR by Issue Year", x = "Issue Year") +
  scale_size_continuous(breaks = c(1000000, 2000000, 3000000, 4000000, 5000000), 
                        labels = c("1m", "2m", "3m", "4m", "5m"))

ggplot(LR_By_Top_Agent, aes(x = AGTOPNAMEL, y = LR, size = Premiums_Sum)) +
  geom_point(col = "blue", alpha = .5) +
  theme(axis.text.x = element_text(angle = -30, vjust = 1, hjust = 0)) +
  labs(title = "ITD LR by Top Agent", x = "Top Agent", size = "Total Premiums") +
  scale_size_continuous(breaks = c(1000000, 2000000, 3000000, 5000000, 10000000, 15000000), 
                        labels = c("1m", "2m", "3m", "5m", "10m", "15m"))

ggplot(LR_By_Issue_State, aes(x = PISSUEST, y = LR, size = Premiums_Sum)) +
  geom_point(col = "blue", alpha = .5) +
  theme(axis.text.x = element_text(angle = -30, vjust = 1, hjust = 0)) +
  labs(title = "ITD LR by Issue State", x = "Issue State", size = "Total Premiums") +
  scale_size_continuous(breaks = c(500000, 1500000, 2500000, 3500000), labels = c("500k", "1.5m", "2.5m", "3.5m")) +
  scale_y_continuous(breaks = c(0, 25, 50, 75, 100, 125, 150))

ggplot(LR_By_Gender, aes(x = PSCD09, y = LR)) +
  geom_bar(stat = "identity", fill = "blue") +
  labs(title = "ITD LR by Gender", x = "Gender")

ggplot(LR_By_Issue_Age, aes(x = PSNO13, y = LR)) +
  geom_line() +
  geom_point(aes(size = Premiums_Sum), col = "blue", alpha = .5) +
  scale_x_continuous(breaks = c(20, 30, 40, 50, 60, 70)) +
  scale_size_continuous(breaks = c(250000, 500000, 750000, 1000000, 1250000), labels = c("250k", "500k", "750k", "1m", "1.25m")) +
  labs(title = "ITD LR by Issue Age", x = "Issue Age")

LR_By_Issue_Age_Gender %>%
  filter(LR < 150, Policy_Count > 20) %>%
  ggplot(aes(x = PSNO13, y = LR, col = PSCD09)) +
  geom_line() +
  geom_point(aes(size = Policy_Count), alpha = .5) +
  geom_smooth(se = FALSE) +
  labs(title = "ITD LR by Issue Age & Gender", x = "Issue Age", size = "Policy Count", col = "Gender")

LR_By_Issue_Age_Gender %>%
  filter(LR < 150, Policy_Count > 20) %>%
  ggplot(aes(x = PSNO13, y = LR)) +
  geom_line(col = "blue") +
  geom_point(aes(size = Policy_Count), alpha = .5, col = "blue") +
  geom_smooth(se = FALSE, col = "red") +
  facet_wrap(~ PSCD09) +
  scale_x_continuous(breaks = c(20, 30, 40, 50, 60, 70)) +
  labs(title = "ITD LR by Issue Age & Gender", x = "Issue Age", size = "Policy Count")

LR_By_Product_Age %>%
  filter(LR <= 150, Policy_Count > 20) %>%
  ggplot(aes(x = PSNO13, y = LR)) +
  geom_line(col = "blue") +
  geom_point(aes(size = Policy_Count), alpha = .5, col = "blue") +
  geom_smooth(se = FALSE, col = "red") +
  facet_wrap(~ Product_Type) +
  labs(title = "ITD LR by Issue Age & Product Type", x = "Issue Age", size = "Policy Count") +
  scale_y_continuous(breaks = c(0, 25, 50, 75, 100, 125, 150, 175))

LR_By_Product_Age_Gender %>%
  filter(LR <= 150, Policy_Count > 20) %>%
  ggplot(aes(x = PSNO13, y = LR, col = PSCD09)) +
  geom_line() +
  geom_point(aes(size = Policy_Count), alpha = .5) +
  geom_smooth(aes(col = PSCD09), se = FALSE) +
  facet_wrap(~ Product_Type) +
  labs(title = "ITD LR by Issue Age, Gender, & Product Type", x = "Issue Age", size = "Policy Count", col = "Gender") +
  scale_y_continuous(breaks = c(0, 25, 50, 75, 100, 125, 150, 175))

LR_By_Product_Age_Gender %>%
  filter(LR <= 150, Policy_Count > 20) %>%
  ggplot(aes(PSNO13)) +
  geom_bar(stat = "identity", aes(y = Prems_Per_Pol), alpha = .8, fill = "green") +
  geom_bar(stat = "identity", aes(y = Claims_Per_Pol), alpha = .7, fill = "red") +
  facet_wrap(Product_Type ~ PSCD09, scales = "free_x") +
  scale_y_continuous(breaks = c(0, 250, 500, 750, 1000, 1250, 1500, 1750, 2000, 2250, 2500)) +
  scale_x_continuous(breaks = c(20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70)) +
  labs(title = "Claims and Premiums Per Policy by Gender, Product Type & Issue Age", y = "Premiums/Claims Per Policy",
       x = "Issue Age")

write_csv(HPHI_Full_Data2, "HPHI_Full_Data_2")
write_csv(LR_By_Top_Agent, "LR_By_Top_Agent")
write_csv(LR_By_Agent_Top_Twenty, "LR_By_Top_Agent")
write_csv(LR_By_Issue_State, "LR_By_Issue_State")

