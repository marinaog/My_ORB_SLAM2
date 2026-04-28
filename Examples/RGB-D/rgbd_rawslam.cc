/**
* This file is part of ORB-SLAM2.
*
* Copyright (C) 2014-2016 Raúl Mur-Artal <raulmur at unizar dot es> (University of Zaragoza)
* For more information see <https://github.com/raulmur/ORB_SLAM2>
*
* ORB-SLAM2 is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* ORB-SLAM2 is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with ORB-SLAM2. If not, see <http://www.gnu.org/licenses/>.
*/


#include<iostream>
#include<algorithm>
#include<fstream>
#include<chrono>
#include<iomanip>
#include<sstream>

#include<opencv2/core/core.hpp>
#include<opencv2/imgcodecs.hpp>
#include<unistd.h>
#include<sys/stat.h>

#include<System.h>

using namespace std;

void LoadImages(const string &strAssociationFilename, vector<string> &vstrImageFilenamesRGB,
                vector<string> &vstrImageFilenamesD, vector<double> &vTimestamps);

static void mkdirp(const string &path)
{
    for(size_t i = 1; i <= path.size(); ++i)
        if(i == path.size() || path[i] == '/')
            mkdir(path.substr(0, i).c_str(), 0755);
}

int main(int argc, char **argv)
{
    if(argc != 5 && argc != 6)
    {
        cerr << endl << "Usage: ./rgbd_tum path_to_vocabulary path_to_settings path_to_sequence path_to_association [output_dir]" << endl;
        return 1;
    }

    string outputDir = (argc == 6) ? string(argv[5]) : ".";
    if(argc == 6)
        mkdirp(outputDir);

    // Retrieve paths to images
    vector<string> vstrImageFilenamesRGB;
    vector<string> vstrImageFilenamesD;
    vector<double> vTimestamps;
    string strAssociationFilename = string(argv[4]);
    LoadImages(strAssociationFilename, vstrImageFilenamesRGB, vstrImageFilenamesD, vTimestamps);

    // Check consistency in the number of images and depthmaps
    int nImages = vstrImageFilenamesRGB.size();
    if(vstrImageFilenamesRGB.empty())
    {
        cerr << endl << "No images found in provided path." << endl;
        return 1;
    }
    else if(vstrImageFilenamesD.size()!=vstrImageFilenamesRGB.size())
    {
        cerr << endl << "Different number of images for rgb and depth." << endl;
        return 1;
    }

    // Create SLAM system. It initializes all system threads and gets ready to process frames.
    bool useViewer = (getenv("ORBSLAM_VIEWER") != nullptr);
    ORB_SLAM2::System SLAM(argv[1],argv[2],ORB_SLAM2::System::RGBD,useViewer);

    // Vector for tracking time statistics
    vector<float> vTimesTrack;
    vTimesTrack.resize(nImages);

    cout << endl << "-------" << endl;
    cout << "Start processing sequence ..." << endl;
    cout << "Images in the sequence: " << nImages << endl << endl;

    // Main loop
    cv::Mat imRGB, imD;
    bool bIs16bit = false;
    for(int ni=0; ni<nImages; ni++)
    {
        // Read image and depthmap from file — IMREAD_UNCHANGED preserves 16-bit HDR data
        imRGB = cv::imread(string(argv[3])+"/"+vstrImageFilenamesRGB[ni],cv::IMREAD_UNCHANGED);
        imD = cv::imread(string(argv[3])+"/"+vstrImageFilenamesD[ni],cv::IMREAD_UNCHANGED);
        double tframe = vTimestamps[ni];

        if(imRGB.empty())
        {
            cerr << endl << "Failed to load image at: "
                 << string(argv[3]) << "/" << vstrImageFilenamesRGB[ni] << endl;
            return 1;
        }

        if(ni == 0)
        {
            bIs16bit = (imRGB.depth() == CV_16U);

            const string depthStr = (imRGB.depth() == CV_8U)  ? "CV_8U"  :
                                    (imRGB.depth() == CV_16U) ? "CV_16U" :
                                    (imRGB.depth() == CV_32F) ? "CV_32F" : "unknown";

            // Compute actual pixel value range on one channel to confirm the
            // full 16-bit range is present (not silently clamped to 0-255).
            cv::Mat ch0;
            if (imRGB.channels() > 1)
                cv::extractChannel(imRGB, ch0, 0);
            else
                ch0 = imRGB;
            double minVal, maxVal;
            cv::minMaxLoc(ch0, &minVal, &maxVal);

            cout << "\n[Image check] Path : " << string(argv[3]) << "/" << vstrImageFilenamesRGB[ni] << endl;
            cout << "[Image check] Type : " << depthStr << "C" << imRGB.channels()
                 << "  (" << imRGB.cols << "x" << imRGB.rows << ")" << endl;
            cout << "[Image check] Range: [" << minVal << ", " << maxVal << "]"
                 << "  (16-bit max = 65535)" << endl;

            if (!bIs16bit)
                cerr << "[Image check] WARNING: expected CV_16U but image loaded as " << depthStr
                     << " — check that the file is a true 16-bit PNG and imread used IMREAD_UNCHANGED\n";
            else if (maxVal <= 255.0)
                cerr << "[Image check] WARNING: image is CV_16U but max pixel = " << maxVal
                     << " — values look clamped to 8-bit range; verify the source PNG is genuinely 16-bit\n";
            else
                cout << "[Image check] OK: 16-bit HDR data confirmed.\n";
            cout << endl;
        }

#ifdef COMPILEDWITHC11
        std::chrono::steady_clock::time_point t1 = std::chrono::steady_clock::now();
#else
        std::chrono::monotonic_clock::time_point t1 = std::chrono::monotonic_clock::now();
#endif

        // Pass the image to the SLAM system
        SLAM.TrackRGBD(imRGB,imD,tframe);

#ifdef COMPILEDWITHC11
        std::chrono::steady_clock::time_point t2 = std::chrono::steady_clock::now();
#else
        std::chrono::monotonic_clock::time_point t2 = std::chrono::monotonic_clock::now();
#endif

        double ttrack= std::chrono::duration_cast<std::chrono::duration<double> >(t2 - t1).count();

        vTimesTrack[ni]=ttrack;

        // Progress bar on stderr so it doesn't mix with SLAM's stdout messages.
        {
            const int barW = 35;
            float pct = (float)(ni + 1) / nImages;
            int filled = (int)(pct * barW);

            // Cumulative average tracking time -> ETA
            double cumTime = 0;
            for (int k = 0; k <= ni; ++k) cumTime += vTimesTrack[k];
            double avgTime = cumTime / (ni + 1);
            int etaSec = (int)(avgTime * (nImages - ni - 1));

            std::ostringstream bar;
            bar << "\r  [" << std::setw(5) << (ni+1) << "/" << nImages << "] [";
            for (int b = 0; b < barW; ++b)
                bar << (b < filled ? '=' : (b == filled ? '>' : ' '));
            bar << "] " << std::fixed << std::setprecision(0) << (pct * 100) << "%"
                << "  " << std::setprecision(2) << avgTime << "s/frame"
                << "  ETA " << etaSec/60 << "m" << std::setw(2) << std::setfill('0') << etaSec%60 << "s"
                << std::setfill(' ');
            std::cerr << bar.str() << std::flush;
            if (ni == nImages - 1) std::cerr << "\n";
        }

        // Wait to load the next frame
        double T=0;
        if(ni<nImages-1)
            T = vTimestamps[ni+1]-tframe;
        else if(ni>0)
            T = tframe-vTimestamps[ni-1];

        if(ttrack<T)
            usleep((T-ttrack)*1e6);
    }

    // Stop all threads
    SLAM.Shutdown();

    // Tracking time statistics
    sort(vTimesTrack.begin(),vTimesTrack.end());
    float totaltime = 0;
    for(int ni=0; ni<nImages; ni++)
    {
        totaltime+=vTimesTrack[ni];
    }
    cout << "-------" << endl << endl;
    cout << "median tracking time: " << vTimesTrack[nImages/2] << endl;
    cout << "mean tracking time: " << totaltime/nImages << endl;

    // Save camera trajectory
    SLAM.SaveTrajectoryTUM(outputDir + "/CameraTrajectory.txt");
    SLAM.SaveKeyFrameTrajectoryTUM(outputDir + "/KeyFrameTrajectory.txt");   

    return 0;
}

void LoadImages(const string &strAssociationFilename, vector<string> &vstrImageFilenamesRGB,
                vector<string> &vstrImageFilenamesD, vector<double> &vTimestamps)
{
    ifstream fAssociation;
    fAssociation.open(strAssociationFilename.c_str());
    while(!fAssociation.eof())
    {
        string s;
        getline(fAssociation,s);
        if(!s.empty())
        {
            stringstream ss;
            ss << s;
            double t;
            string sRGB, sD;
            ss >> t;
            vTimestamps.push_back(t);
            ss >> sRGB;
            vstrImageFilenamesRGB.push_back(sRGB);
            ss >> t;
            ss >> sD;
            vstrImageFilenamesD.push_back(sD);

        }
    }
}
