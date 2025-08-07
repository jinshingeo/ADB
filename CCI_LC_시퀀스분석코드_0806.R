# ##############################################################################
# 중요 -> 제 로컬 환경에서는 램용량 부족때문인지, 분석이 안돌아갑니다..
# 정상적으로 코드가 돌아가는지 확인은 못한 상황입니다....
# ##############################################################################
# 이 스크립트는 전처리된 우즈베키스탄 토지 피복 시계열 데이터(CSV)를 사용하여
# TraMineR 패키지를 활용한 시퀀스 분석을 수행
#
# 프로세스 요약:
# 1. 라이브러리 로드 및 파일 불러오기
# 2. CCI-LC 범례(Legend)에 기반하여 시퀀스 상태(알파벳, 라벨, 색상) 정의
# 3. 시퀀스 객체(seqdef) 생성
# 4. 시퀀스 분포도 시각화
# 5. 최적 이동 비용(OM)을 사용한 시퀀스 거리 계산 및 계층적 군집화
# 6. 실루엣 계수를 이용한 최적 군집 수 탐색
# 7. 군집 결과 시각화 및 최종 결과 저장
#
# ##############################################################################


# --- 1단계: 라이브러리 로드 및 데이터 불러오기 ---
# 필요한 패키지 설치


library(readr)
library(TraMineR)
library(vegan)
library(cluster)
library(RColorBrewer) 

# 전처리 시 생성된 CSV 파일을 불러옵니다.
# 파일 경로는 실제 파일이 위치한 곳으로 지정해야 합니다.
land_cover_data <- read_csv("./output/uzbekistan_pixel_timeseries.csv")


# --- 2단계: 토지 피복 범례(Legend) 정의 ---
# PDF(CCI-LC_Maps_Legend)의 정보를 기반으로 상태(State) 정의
# 이것이 시퀀스 분석의 '알파벳'이 됩니다. -> 이전 분석 시 이 부분 설정과정에서 오류가 많이 발생했었습니다..
cci_alphabet <- c(
  10, 11, 12, 20, 30, 40, 50, 60, 61, 62, 70, 71, 72, 80, 81, 82, 90, 
  100, 110, 120, 121, 122, 130, 140, 150, 151, 152, 153, 160, 170, 
  180, 190, 200, 201, 202, 210, 220
)

# 각 숫자 값에 해당하는 라벨(설명)을 정의합니다.
cci_labels <- c(
  "Cropland, rainfed", "Herbaceous cover (Rainfed)", "Tree or shrub cover (Rainfed)",
  "Cropland, irrigated", "Mosaic cropland (>50%)", "Mosaic natural vegetation (>50%)",
  "Tree cover, broadleaved, evergreen", "Tree cover, broadleaved, deciduous",
  "Tree cover, broadleaved, deciduous, closed", "Tree cover, broadleaved, deciduous, open",
  "Tree cover, needleleaved, evergreen", "Tree cover, needleleaved, evergreen, closed",
  "Tree cover, needleleaved, evergreen, open", "Tree cover, needleleaved, deciduous",
  "Tree cover, needleleaved, deciduous, closed", "Tree cover, needleleaved, deciduous, open",
  "Tree cover, mixed leaf type", "Mosaic tree and shrub (>50%)", "Mosaic herbaceous cover (>50%)",
  "Shrubland", "Evergreen shrubland", "Deciduous shrubland", "Grassland", "Lichens and mosses",
  "Sparse vegetation (<15%)", "Sparse tree (<15%)", "Sparse shrub (<15%)", "Sparse herbaceous cover (<15%)",
  "Tree cover, flooded, fresh water", "Tree cover, flooded, saline water",
  "Shrub or herbaceous cover, flooded", "Urban areas", "Bare areas", "Consolidated bare areas",
  "Unconsolidated bare areas", "Water bodies", "Permanent snow and ice"
)

# 시각화를 위한 색상 팔레트를 생성합니다. 상태가 많으므로 여러 팔레트를 조합합니다.
# 상태의 개수(37개)에 맞춰 랜덤으로 색상을 생성합니다.
qual_col_pals <- brewer.pal.info[brewer.pal.info$category == 'qual',]
col_vector <- unlist(mapply(brewer.pal, qual_col_pals$maxcolors, rownames(qual_col_pals)))
cci_colors <- colorRampPalette(col_vector)(length(cci_alphabet))


# --- 3단계: 시퀀스 객체 생성 ---
# TraMineR의 seqdef 함수를 사용하여 시퀀스 객체를 생성합니다.
print("시퀀스 객체를 생성합니다.")
seq_lc <- seqdef(
  land_cover_data,
  var = 3:ncol(land_cover_data), # 중요: 데이터가 3번째 열('1992')부터 시작
  states = cci_alphabet,         # 숫자 기반의 알파벳 사용
  labels = cci_labels,           # 위에서 정의한 라벨
  cpal = cci_colors,             # 위에서 정의한 색상 팔레트
  missing = 0,                   # 중요: '0' 값은 'No Data'이므로 결측값으로 처리
  xtstep = 5                     # x축 레이블을 5년 단위로 표시
)
print("시퀀스 객체 생성 완료.")


# --- 4단계: 시퀀스 분포도 시각화 ---
# 전체 데이터의 토지 피복 변화 상태를 시각화합니다.
print("전체 시퀀스 분포도를 그립니다...")
par(mar = c(4, 4, 4, 2)) # 그래프 여백 설정
seqdplot(seq_lc, border = NA, with.legend = "right", 
         main = "Land Cover Sequence Distribution (Uzbekistan)")


# --- 5단계: 시퀀스 거리 계산 및 계층적 군집화 ---
# Optimal Matching(OM) 방법을 사용하여 시퀀스 간의 거리를 계산합니다.
# 이동(indel)과 대체(substitution) 비용을 설정합니다. -> 분석 목적에 맞게 이 부분을 조절하면 됩니다..!
print("시퀀스 간 거리를 계산하고 계층적 군집화를 수행합니다...")
cost_matrix <- seqcost(seq_lc, method = "CONSTANT", cval = 2) # 모든 대체 비용을 2로 설정
dist_matrix <- seqdist(seq_lc, method = "OM", indel = 1, sm = cost_matrix$sm) # 이동 비용 1

# Ward's method를 사용한 계층적 군집화
hc <- hclust(as.dist(dist_matrix), method = "ward.D2")
plot(hc, main = "Hierarchical Clustering of Land Cover Sequences", xlab = "", sub = "")


# --- 6단계: 최적 군집 수 탐색 ---
# 실루엣 계수(Silhouette Score)를 사용하여 최적의 군집 수를 결정합니다.
print("최적의 군집 수를 탐색합니다 (실루엣 계수 계산)...")
silhouette_score <- function(k){
  cl <- cutree(hc, k = k)
  ss <- silhouette(cl, dist = dist_matrix)
  mean(ss[, 3])
}

# 2개부터 10개까지의 군집에 대해 평균 실루엣 점수를 계산합니다. 대략 10개로 해뒀는데, 목적에 맞게 변경하면 됩니다.
k_values <- 2:10
avg_sil_scores <- sapply(k_values, silhouette_score)

# 결과 시각화
plot(k_values, avg_sil_scores, type = "b", pch = 19, frame = FALSE, 
     xlab = "Number of Clusters (k)", ylab = "Average Silhouette Score",
     main = "Optimal Number of Clusters by Silhouette Score")
# 그래프에서 꺾이는 지점이나 가장 높은 점수가 최적의 k가 될 수 있습니다. 저는 가장 높은 지점을 K로 했었습니다.


# --- 7단계: 군집 결과 시각화 및 저장 ---
# 위 그래프를 바탕으로 최종 군집 수를 결정합니다. (여기서는 예시로 10개 사용)
# **아래 n_cluster 값은 6단계 그래프를 보고 직접 조정해야 합니다.**
n_cluster <- 10
print(paste0(n_cluster, "개의 군집으로 결과를 저장하고 시각화합니다..."))

# 군집 할당
seq_cluster <- cutree(hc, k = n_cluster)
seq_cluster.labels <- factor(seq_cluster, labels = paste0("Cluster ", 1:n_cluster))

# 원본 데이터에 군집 정보 추가
land_cover_data$Cluster <- seq_cluster.labels

# 군집별 시퀀스 분포도 시각화
seqdplot(seq_lc, group = seq_cluster.labels, border = NA, with.legend = "right",
         main = paste(n_cluster, "Clusters of Land Cover Sequences"))

# 최종 결과 CSV 파일로 저장
output_filename <- "./output/uzbekistan_sequence_clusters.csv"
write.csv(land_cover_data, output_filename, row.names = FALSE)

print(paste0("모든 과정 완료! 최종 결과가 '", output_filename, "' 파일로 저장되었습니다."))
print("CSV 파일에는 각 픽셀의 위도, 경도, 연도별 데이터 및 소속 군집 정보가 포함됩니다.")