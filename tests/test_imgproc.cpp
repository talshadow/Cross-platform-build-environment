#include <gtest/gtest.h>
#include <opencv2/imgproc.hpp>

TEST(ImgProc, GaussianBlurDoesNotThrow)
{
    cv::Mat src(64, 64, CV_8UC1, cv::Scalar(128));
    cv::Mat dst;
    EXPECT_NO_THROW(cv::GaussianBlur(src, dst, {5, 5}, 1.0));
    EXPECT_EQ(dst.size(), src.size());
}

TEST(ImgProc, CvtColorBGR2Gray)
{
    cv::Mat bgr(8, 8, CV_8UC3, cv::Scalar(100, 150, 200));
    cv::Mat gray;
    cv::cvtColor(bgr, gray, cv::COLOR_BGR2GRAY);
    EXPECT_EQ(gray.type(), CV_8UC1);
    EXPECT_EQ(gray.size(), bgr.size());
}
