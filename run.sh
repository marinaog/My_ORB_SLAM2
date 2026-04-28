#!/bin/bash

declare -A ASSOCIATIONS=(
    [rgbd_dataset_freiburg1_desk]=Examples/RGB-D/associations/fr1_desk.txt
    #[rgbd_dataset_freiburg1_room]=Examples/RGB-D/associations/fr1_room.txt
)

for SCENE in "${!ASSOCIATIONS[@]}"; do
    DIR=results/$SCENE/$SCENE
    N=2; while [ -d "$DIR" ]; do DIR=results/$SCENE/${SCENE}_$N; N=$((N+1)); done

    ./Examples/RGB-D/rgbd_tum \
        Examples/Vocabulary/ORBvoc.txt \
        Examples/RGB-D/TUM1.yaml \
        datasets/rawslam/$SCENE \
        ${ASSOCIATIONS[$SCENE]} \
        $DIR

	evo_ape tum datasets/tum/$SCENE/groundtruth.txt $DIR/KeyFrameTrajectory.txt \
		 --align --correct_scale --save_plot $DIR/ate_plot.png
done
