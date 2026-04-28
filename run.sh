#!/bin/bash
export ORBSLAM_VIEWER=0

declare -A ASSOCIATIONS=(
    [cabin]=Examples/RGB-D/associations/rawslam_cabin.txt
    [coat_rack]=Examples/RGB-D/associations/rawslam_coat_rack.txt
    [boxes]=Examples/RGB-D/associations/rawslam_boxes.txt
    [candles]=Examples/RGB-D/associations/rawslam_candles.txt
    [christmas]=Examples/RGB-D/associations/rawslam_christmas.txt
    [coffee]=Examples/RGB-D/associations/rawslam_coffee.txt
    [kitchen]=Examples/RGB-D/associations/rawslam_kitchen.txt
    [nerdy_robot]=Examples/RGB-D/associations/rawslam_nerdy_robot.txt
    [boxes]=Examples/RGB-D/associations/rawslam_boxes.txt
)

for SCENE in "${!ASSOCIATIONS[@]}"; do
    echo ""; echo "=== [$SCENE]  associations  ==="
    python3 associate_rawslam.py datasets/rawslam/$SCENE
    for RUN in {1..3}; do
        DIR=results/$SCENE/$SCENE
        DIR_RAW=results/$SCENE/${SCENE}_raw
        N=2; while [ -d "$DIR" ]; do DIR=results/$SCENE/${SCENE}_$N; N=$((N+1)); done
        N=2; while [ -d "$DIR_RAW" ]; do DIR_RAW=results/$SCENE/${SCENE}_raw_$N; N=$((N+1)); done

        ASSOC=${ASSOCIATIONS[$SCENE]}
        ASSOC_RAW="${ASSOC%.txt}_raw.txt"

        # Normal images
        echo "=== [$SCENE] 1/3  ground truth (sRGB) ==="
        python3 gt_tum.py datasets/rawslam/$SCENE
        echo "=== [$SCENE] 2/3  ORB-SLAM2 (sRGB) -> $DIR ==="
        ./Examples/RGB-D/rgbd_rawslam \
            Examples/Vocabulary/ORBvoc.txt \
            Examples/RGB-D/rawslam.yaml \
            datasets/rawslam/$SCENE \
            $ASSOC \
            $DIR
        echo "=== [$SCENE] 3/3  ATE evaluation (sRGB) ==="
        evo_ape tum datasets/rawslam/$SCENE/groundtruth_tum.txt $DIR/KeyFrameTrajectory.txt \
            --align --correct_scale --save_plot $DIR/ate_plot.png | tee $DIR/ate_metrics.txt

        # RAW IMAGES
        echo ""; echo "=== [$SCENE] 1/3  associations (raw_linear_sRGB) ==="
        python3 associate_rawslam.py datasets/rawslam/$SCENE raw

        echo "=== [$SCENE] 2/3  ORB-SLAM2 (16-bit HDR) -> $DIR_RAW ==="
        ./Examples/RGB-D/rgbd_rawslam \
            Examples/Vocabulary/ORBvoc.txt \
            Examples/RGB-D/rawslam.yaml \
            datasets/rawslam/$SCENE \
            $ASSOC_RAW \
            $DIR_RAW

        echo "=== [$SCENE] 3/3  ATE evaluation (raw) ==="
        evo_ape tum datasets/rawslam/$SCENE/groundtruth_tum.txt $DIR_RAW/KeyFrameTrajectory.txt \
            --align --correct_scale --save_plot $DIR_RAW/ate_plot.png | tee $DIR_RAW/ate_metrics.txt

        echo "=== [$SCENE] done ==="
done
