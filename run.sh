#!/bin/bash
export ORBSLAM_VIEWER=0

SCENES=(
    cabin
    coat_rack
    boxes
    candles
    christmas
    coffee
    kitchen
    nerdy_robot
    small_city
)

for SCENE in "${SCENES[@]}"; do
    echo ""; echo "=== [$SCENE]  associations  ==="
    python3 associate_rawslam.py datasets/rawslam/$SCENE
    python3 associate_rawslam.py datasets/rawslam/$SCENE raw

    for RUN in {1..3}; do
        DIR=results/$SCENE/$SCENE
        DIR_RAW=results/$SCENE/${SCENE}_raw
        N=2; while [ -d "$DIR" ]; do DIR=results/$SCENE/${SCENE}_$N; N=$((N+1)); done
        N=2; while [ -d "$DIR_RAW" ]; do DIR_RAW=results/$SCENE/${SCENE}_raw_$N; N=$((N+1)); done

        ASSOC=Examples/RGB-D/associations/rawslam_${SCENE}.txt
        ASSOC_RAW=Examples/RGB-D/associations/rawslam_${SCENE}_raw.txt

        # Normal images
        echo "=== [$SCENE] 1/3  ground truth (sRGB) ==="
        python3 gt_tum.py datasets/rawslam/$SCENE
        echo "=== [$SCENE] 2/3  ORB-SLAM2 (sRGB) -> $DIR ==="
        ./Examples/RGB-D/rgbd_rawslam \
            Examples/Vocabulary/ORBvoc.txt \
            Examples/RGB-D/rawslam.yaml \
            datasets/rawslam/$SCENE \
            $ASSOC \
            $DIR |& tee $DIR/log.txt
        echo "=== [$SCENE] 3/3  ATE evaluation (sRGB) ==="
        evo_ape tum datasets/rawslam/$SCENE/groundtruth_tum.txt $DIR/KeyFrameTrajectory.txt \
            --align --correct_scale --save_plot $DIR/ate_plot.png | tee $DIR/ate_metrics.txt

        # RAW IMAGES
        echo "=== [$SCENE] 1/2  ORB-SLAM2 (16-bit HDR) -> $DIR_RAW ==="
        ./Examples/RGB-D/rgbd_rawslam \
            Examples/Vocabulary/ORBvoc.txt \
            Examples/RGB-D/rawslam.yaml \
            datasets/rawslam/$SCENE \
            $ASSOC_RAW \
            $DIR_RAW |& tee $DIR_RAW/log.txt

        echo "=== [$SCENE] 2/2  ATE evaluation (raw) ==="
        evo_ape tum datasets/rawslam/$SCENE/groundtruth_tum.txt $DIR_RAW/KeyFrameTrajectory.txt \
            --align --correct_scale --save_plot $DIR_RAW/ate_plot.png | tee $DIR_RAW/ate_metrics.txt

        echo "=== [$SCENE] done ==="
    done
done
