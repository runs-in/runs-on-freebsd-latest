#!/usr/bin/env python3
import cv2
import pytesseract
import numpy
import sys;

img = cv2.imread(sys.argv[1])

gray = cv2.cvtColor(img, cv2.COLOR_RGB2GRAY)
gray, img_bin = cv2.threshold(gray, 128, 255, cv2.THRESH_BINARY | cv2.THRESH_OTSU)
gray = cv2.bitwise_not(img_bin)

kernel = numpy.ones((2, 1), numpy.uint8)

img = cv2.erode(gray, kernel, iterations=1)
img = cv2.dilate(img, kernel, iterations=1)

text = pytesseract.image_to_string(img)
print(text)
