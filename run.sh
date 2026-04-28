#!/bin/bash
export ORBSLAM_VIEWER=1

declare -A ASSOCIATIONS=(
    [bottles]=Examples/RGB-D/associations/rawslam_bottles.txt
    #[coat_rack]=Examples/RGB-D/associations/rawslam_coat_rack.txt
    #[boxes]=Examples/RGB-D/associations/rawslam_boxes.txt
)

for SCENE in "${!ASSOCIATIONS[@]}"; do
    DIR=results/$SCENE/$SCENE
    N=2; while [ -d "$DIR" ]; do DIR=results/$SCENE/${SCENE}_$N; N=$((N+1)); done

    ./Examples/RGB-D/rgbd_rawslam \
        Examples/Vocabulary/ORBvoc.txt \
        Examples/RGB-D/rawslam.yaml \
        datasets/rawslam/$SCENE \
        ${ASSOCIATIONS[$SCENE]} \
        $DIR

    evo_ape tum datasets/rawslam/$SCENE/groundtruth_tum.txt $DIR/KeyFrameTrajectory.txt \
         --align --correct_scale --save_plot $DIR/ate_plot.png
done
