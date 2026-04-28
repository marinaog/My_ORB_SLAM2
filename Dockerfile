# 1. Base con Ubuntu 20.04 y CUDA 11.8
FROM nvidia/cuda:11.8.0-devel-ubuntu20.04

# Evitar diálogos interactivos
ENV DEBIAN_FRONTEND=noninteractive

# 2. Instalación de Dependencias del Sistema
RUN apt-get update && apt-get install -y \
    git cmake gcc g++ pkg-config libglew-dev libepoxy-dev \
    libboost-all-dev libssl-dev libopencv-dev \
    libpython2.7-dev python3-numpy wget perl \
    && rm -rf /var/lib/apt/lists/*

# 3. Instalación de Eigen 3.3.9
WORKDIR /opt
RUN wget https://gitlab.com/libeigen/eigen/-/archive/3.3.9/eigen-3.3.9.tar.gz && \
    tar -xf eigen-3.3.9.tar.gz && \
    cd eigen-3.3.9 && mkdir build && cd build && \
    cmake .. && make install && \
    cd /opt && rm -rf eigen-3.3.9*

# 4. Instalación de Pangolin v0.6
WORKDIR /opt
RUN git clone https://github.com/stevenlovegrove/Pangolin.git && \
    cd Pangolin && git checkout v0.6 && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_CXX_FLAGS="-w" -DBUILD_PANGOLIN_PYTHON=OFF && \
    make -j$(nproc) && make install

# 5. Preparar ORB-SLAM2
WORKDIR /app
COPY . .

# --- Paso 6: PARCHES DE COMPATIBILIDAD ---

# 1. Headers de sistema y usleep
RUN sed -i '1i #include <unistd.h>' include/System.h && \
    sed -i '1i #include <unistd.h>' include/Viewer.h && \
    sed -i '1i #include <unistd.h>' src/Viewer.cc

# 2. Corregir incluye de OpenCV y CvMat (PnPsolver y FrameDrawer)
RUN find . -type f \( -name "*.cc" -o -name "*.h" \) -exec sed -i 's/opencv\/cv.h/opencv2\/opencv.hpp/g' {} + && \
    sed -i '1i #include <opencv2/core/types_c.h>\n#include <opencv2/highgui/highgui_c.h>\n#include <opencv2/imgproc/imgproc_c.h>' include/PnPsolver.h && \
    sed -i '1i #include <opencv2/imgproc/types_c.h>' src/FrameDrawer.cc

# 3. REESCRIBIR CMakeLists.txt (DBoW2 y ORB_SLAM2)
RUN printf 'cmake_minimum_required(VERSION 2.8)\nproject(DBoW2)\nset(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${PROJECT_SOURCE_DIR}/lib)\nfind_package(OpenCV REQUIRED)\ninclude_directories(${OpenCV_INCLUDE_DIRS})\nadd_library(DBoW2 SHARED DBoW2/BowVector.cpp DBoW2/FORB.cpp DBoW2/FeatureVector.cpp DBoW2/ScoringObject.cpp DUtils/Random.cpp DUtils/Timestamp.cpp)\ntarget_link_libraries(DBoW2 ${OpenCV_LIBS})' > Thirdparty/DBoW2/CMakeLists.txt && \
    printf 'cmake_minimum_required(VERSION 2.8)\nproject(ORB_SLAM2)\nset(CMAKE_BUILD_TYPE Release)\nset(CMAKE_CXX_FLAGS "-O3 -Wall -std=c++11")\nfind_package(OpenCV REQUIRED)\nfind_package(Eigen3 3.1.0 REQUIRED)\nfind_package(Pangolin REQUIRED)\ninclude_directories(${PROJECT_SOURCE_DIR} ${PROJECT_SOURCE_DIR}/include ${EIGEN3_INCLUDE_DIR} ${Pangolin_INCLUDE_DIRS} ${OpenCV_INCLUDE_DIRS} ${PROJECT_SOURCE_DIR}/Thirdparty/DBoW2 ${PROJECT_SOURCE_DIR}/Thirdparty/g2o)\nset(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${PROJECT_SOURCE_DIR}/lib)\nadd_library(${PROJECT_NAME} SHARED src/System.cc src/Tracking.cc src/LocalMapping.cc src/LoopClosing.cc src/ORBextractor.cc src/ORBmatcher.cc src/FrameDrawer.cc src/Converter.cc src/MapPoint.cc src/KeyFrame.cc src/Map.cc src/MapDrawer.cc src/Optimizer.cc src/PnPsolver.cc src/Frame.cc src/KeyFrameDatabase.cc src/Sim3Solver.cc src/Initializer.cc src/Viewer.cc)\ntarget_link_libraries(${PROJECT_NAME} ${OpenCV_LIBS} ${EIGEN3_LIBS} ${Pangolin_LIBRARIES} ${PROJECT_SOURCE_DIR}/Thirdparty/DBoW2/lib/libDBoW2.so ${PROJECT_SOURCE_DIR}/Thirdparty/g2o/lib/libg2o.so)\nadd_executable(rgbd_tum Examples/RGB-D/rgbd_tum.cc)\ntarget_link_libraries(rgbd_tum ${PROJECT_NAME})\nadd_executable(mono_tum Examples/Monocular/mono_tum.cc)\ntarget_link_libraries(mono_tum ${PROJECT_NAME})' > CMakeLists.txt

# 4. Parche masivo de constantes OpenCV 4 (Incluyendo Sim3Solver)
RUN find . -type f \( -name "*.cc" -o -name "*.h" \) -exec sed -i 's/CV_BGR2GRAY/cv::COLOR_BGR2GRAY/g' {} + && \
    find . -type f \( -name "*.cc" -o -name "*.h" \) -exec sed -i 's/CV_RGB2GRAY/cv::COLOR_RGB2GRAY/g' {} + && \
    find . -type f \( -name "*.cc" -o -name "*.h" \) -exec sed -i 's/CV_RGBA2GRAY/cv::COLOR_RGBA2GRAY/g' {} + && \
    find . -type f \( -name "*.cc" -o -name "*.h" \) -exec sed -i 's/CV_BGRA2GRAY/cv::COLOR_BGRA2GRAY/g' {} + && \
    find . -type f \( -name "*.cc" -o -name "*.h" \) -exec sed -i 's/CV_LOAD_IMAGE_UNCHANGED/cv::IMREAD_UNCHANGED/g' {} + && \
    find . -type f \( -name "*.cc" -o -name "*.h" \) -exec sed -i 's/CV_LOAD_IMAGE_COLOR/cv::IMREAD_COLOR/g' {} + && \
    find . -type f \( -name "*.cc" -o -name "*.h" \) -exec sed -i 's/CV_FONT_HERSHEY_SIMPLEX/cv::FONT_HERSHEY_SIMPLEX/g' {} + && \
    find . -type f \( -name "*.cc" -o -name "*.h" \) -exec sed -i 's/CV_AA/cv::LINE_AA/g' {} + && \
    find . -type f \( -name "*.cc" -o -name "*.h" \) -exec sed -i 's/CV_REDUCE_SUM/cv::REDUCE_SUM/g' {} + && \
    find . -type f \( -name "*.cc" -o -name "*.h" \) -exec sed -i 's/CV_REDUCE_AVG/cv::REDUCE_AVG/g' {} +

# 5. PARCHE PARA ALIGNED_ALLOCATOR
RUN perl -pi -e 's/std::pair<const KeyFrame\*, g2o::Sim3>/std::pair<KeyFrame\* const, g2o::Sim3>/g' include/LoopClosing.h && \
    perl -pi -e 's/std::pair<const KeyFrame\*, g2o::Sim3>/std::pair<KeyFrame\* const, g2o::Sim3>/g' src/LoopClosing.cc

# 6. PARCHE monotonic_clock -> steady_clock (renombrado en C++11)
RUN find . -type f \( -name "*.cc" -o -name "*.cpp" \) -exec sed -i 's/chrono::monotonic_clock/chrono::steady_clock/g' {} +

# --- Paso 7: Compilación ---
ENV CXXFLAGS="-w"
SHELL ["/bin/bash", "-c"]
RUN chmod +x build.sh && \
    sed -i 's/make -j$/make -j$(nproc)/g; s/make -j /make -j$(nproc) /g' build.sh && \
    ./build.sh

# Configuración final
ENV PATH="/app/Examples/Monocular:${PATH}"
CMD ["bash"]
