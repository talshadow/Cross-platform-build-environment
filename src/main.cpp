#include <cstdlib>
#include <iostream>
#include <string>

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

int main(int argc, char* argv[])
{
    if (argc != 3) {
        std::cerr << "Usage: " << argv[0] << " <input_image> <output_image>\n";
        return EXIT_FAILURE;
    }

    const std::string input_path  = argv[1];
    const std::string output_path = argv[2];

    cv::Mat src = cv::imread(input_path, cv::IMREAD_COLOR);
    if (src.empty()) {
        std::cerr << "Cannot read image: " << input_path << "\n";
        return EXIT_FAILURE;
    }

    cv::Mat gray;
    cv::cvtColor(src, gray, cv::COLOR_BGR2GRAY);

    cv::Mat blurred;
    cv::GaussianBlur(gray, blurred, {7, 7}, 1.5);

    cv::Mat edges;
    cv::Canny(blurred, edges, 50, 150);

    if (!cv::imwrite(output_path, edges)) {
        std::cerr << "Cannot write image: " << output_path << "\n";
        return EXIT_FAILURE;
    }

    std::cout << "Saved edge map to " << output_path << "\n";
    return EXIT_SUCCESS;
}
