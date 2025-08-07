# ##############################################################################
#
# 이 스크립트는 다중 밴드(Multi-band) GeoTIFF 래스터 데이터를 특정 국가 경계에 맞춰
# 자른(Clip) 후, 시계열 픽셀 데이터를 CSV 파일로 변환하는 전처리 과정을 수행합니다.
#
# 프로세스 요약:
# 1. 라이브러리 임포트 및 기본 경로 설정
# 2. 대용량 TIF 파일과 국가 경계 Shapefile 로드
# 3. 래스터 데이터를 국가 경계에 맞춰 클리핑 및 중간 결과 저장
# 4. 클리핑된 데이터의 속성 탐색 및 시각화
# 5. 최종 래스터 데이터를 연도별 픽셀 값을 갖는 Wide-format의 CSV로 변환 및 저장
#
# ##############################################################################


# --- 1단계: 라이브러리 임포트 ---
import pandas as pd
import rioxarray as rio
import geopandas as gpd
import matplotlib.pyplot as plt

print("--- 1단계: 필요 라이브러리 임포트 완료 ---\n")


# --- 2단계: 파일 경로 및 주요 변수 설정 ---
# 분석에 필요한 파일들의 경로와 주요 변수들을 여기서 관리합니다.
TIF_PATH = './data/ESACCI-LC-L4-LCCS-Map-300m-P1Y-1992_2015.tif'
SHAPEFILE_PATH = './data/ne_110m_admin_0_countries/ne_110m_admin_0_countries.shp'
OUTPUT_CLIPPED_TIF_PATH = './output/uzbekistan_clipped_raster.tif' # 클리핑된 결과 TIF 저장 경로
OUTPUT_CSV_PATH = './output/uzbekistan_pixel_timeseries.csv'     # 최종 CSV 저장 경로

TARGET_COUNTRY = 'Uzbekistan' # 분석 대상 국가
START_YEAR = 1992             # 데이터의 시작 연도

print("--- 2단계: 파일 경로 및 변수 설정 완료 ---\n")


# --- 3단계: 데이터 로딩 및 클리핑 ---
try:
    # 3-1. 래스터 및 Shapefile 불러오기
    print(f"3-1. 데이터 로딩을 시작합니다...")
    print(f" - 래스터 파일: '{TIF_PATH}'")
    # chunks='auto' 옵션은 Dask를 활용하여 대용량 파일을 메모리에 모두 올리지 않고 효율적으로 처리하게 합니다.
    raster_data = rio.open_rasterio(TIF_PATH, chunks='auto')

    print(f" - Shapefile: '{SHAPEFILE_PATH}'")
    world_boundaries = gpd.read_file(SHAPEFILE_PATH)
    print("래스터 및 Shapefile 로딩 성공!\n")

    # 3-2. 분석 지역 경계 추출 및 좌표계 통일
    print(f"3-2. '{TARGET_COUNTRY}'의 경계 정보를 추출하고 좌표계를 통일합니다...")
    target_geom = world_boundaries[world_boundaries.ADMIN == TARGET_COUNTRY]

    if target_geom.empty:
        raise ValueError(f"Shapefile의 'ADMIN' 컬럼에서 '{TARGET_COUNTRY}'을(를) 찾을 수 없습니다.")

    # 래스터 데이터의 좌표계(CRS)에 맞춰 Shapefile의 좌표계를 변환합니다.
    target_geom_reprojected = target_geom.to_crs(raster_data.rio.crs)
    print("좌표계 통일 완료.\n")

    # 3-3. 래스터 데이터 클리핑
    print("3-3. 래스터 데이터를 국가 경계에 맞춰 클리핑합니다...")
    # rioxarray의 clip 기능을 사용하여 래스터를 잘라냅니다.
    clipped_raster = raster_data.rio.clip(target_geom_reprojected.geometry.values, drop=True)
    print("클리핑 성공!")
    print(f" - 원본 데이터 shape: {raster_data.shape}")
    print(f" - 클리핑된 데이터 shape: {clipped_raster.shape}\n")

    # 3-4. 클리핑된 결과 파일로 저장 (중간 결과 저장)
    # 이후 분석에서 클리핑 과정을 반복하지 않기 위해, 잘라낸 결과물을 별도 파일로 저장합니다.
    print(f"3-4. 클리핑된 결과를 '{OUTPUT_CLIPPED_TIF_PATH}' 파일로 저장합니다...")
    clipped_raster.rio.to_raster(OUTPUT_CLIPPED_TIF_PATH)
    print("중간 결과 저장 성공!\n")

except FileNotFoundError as e:
    print(f"[오류] 파일을 찾을 수 없습니다: {e}. 경로를 다시 확인해주세요.")
except Exception as e:
    print(f"[오류] 데이터 처리 중 예기치 않은 오류가 발생했습니다: {e}")
    exit() # 오류 발생 시 스크립트 중단

print("--- 3단계: 데이터 로딩 및 클리핑 완료 ---\n")


# --- 4단계: 데이터 탐색 및 시각화 ---
print("--- 4단계: 클리핑된 데이터 탐색 및 시각화 ---")

# 4-1. 데이터 탐색
print("4-1. 데이터 기본 정보 탐색:")
num_bands = clipped_raster.shape[0]
height, width = clipped_raster.shape[1], clipped_raster.shape[2]
resolution = clipped_raster.rio.resolution()
print(f" - 밴드(시점) 수: {num_bands}개")
print(f" - 좌표 체계(CRS): {clipped_raster.rio.crs}")
print(f" - 데이터 크기 (Height x Width): {height} x {width} 픽셀")
print(f" - 해상도 (x, y): ({resolution[0]:.4f}, {resolution[1]:.4f}) 단위\n")

# 4-2. 시각화
print("4-2. 데이터의 첫 번째 밴드(시점)를 시각화합니다...")
plt.figure(figsize=(10, 8))
clipped_raster[0].plot(cmap='viridis') # 첫 번째 밴드(1992년 데이터) 시각화
plt.title(f'Clipped Raster Data for {TARGET_COUNTRY} (First Band)')
plt.xlabel('Longitude')
plt.ylabel('Latitude')
plt.grid(True)
plt.show()
print("시각화 완료.\n")


# --- 5단계: CSV 변환 및 저장 ---
print("--- 5단계: CSV 변환 및 저장 ---")
# 이 단계는 메모리를 많이 사용할 수 있으므로, 매우 큰 데이터의 경우 주의가 필요합니다.

# 5-1. 'band' 좌표를 실제 연도로 변경
print("5-1. 밴드 인덱스를 실제 연도 정보로 변환합니다...")
# 하드코딩 대신, 데이터의 밴드 수와 시작 연도를 바탕으로 동적으로 연도 목록 생성
years = range(START_YEAR, START_YEAR + num_bands)
raster_with_years = clipped_raster.assign_coords(band=years)
raster_with_years.band.attrs['long_name'] = 'Year'
print(f" - 변환된 연도: {years[0]} ~ {years[-1]}\n")

# 5-2. 'Long format' 데이터프레임으로 변환
# 각 행이 (위도, 경도, 연도, 픽셀 값) 형태를 갖는 긴 데이터프레임을 만듭니다.
print("5-2. xarray 객체를 Long-format의 Pandas 데이터프레임으로 변환합니다...")
df_long = raster_with_years.to_dataframe(name='pixel_value').reset_index()
df_long = df_long.rename(columns={'y': 'latitude', 'x': 'longitude', 'band': 'year'})
print("Long-format 데이터프레임 생성 완료.")
print(f" - 형태(Shape): {df_long.shape}\n")

# 5-3. 'Wide format'으로 재구성 (Pivot)
# 각 행은 (위도, 경도)를, 각 열은 연도별 픽셀 값을 갖도록 구조를 변경합니다.
print("5-3. 데이터를 Wide-format으로 재구성합니다...")
df_wide = df_long.pivot_table(
    index=['latitude', 'longitude'],
    columns='year',
    values='pixel_value'
).reset_index()
df_wide.columns.name = None # 불필요한 컬럼 이름 제거
print("Wide-format 데이터프레임으로 재구성 완료.")
print(f" - 형태(Shape): {df_wide.shape}\n")

# 5-4. CSV 파일로 저장
print(f"5-4. 최종 결과를 '{OUTPUT_CSV_PATH}' 파일로 저장합니다...")
df_wide.to_csv(OUTPUT_CSV_PATH, index=False)
print("CSV 파일 저장 성공!\n")

print("--- 모든 전처리 과정이 성공적으로 완료되었습니다. ---")
print("\n생성된 CSV 파일 미리보기 (상위 5행):")
print(df_wide.head())
