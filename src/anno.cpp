#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <ext/matrix_clip_space.hpp>
#include <ext/matrix_transform.hpp>
#include <glm.hpp>
#include <iostream>
#include <stb_image.h>
#include <stb_image_write.h>

#include "camera.hpp"
#include "mesh.hpp"
#include "model.hpp"
#include "scene.hpp"
#include "shader.hpp"

const unsigned int SCR_WIDTH = 1080;
const unsigned int SCR_HEIGHT = 1080;

camera_t camera(glm::vec3(0.0f, 0.0f, 3.0f));
float last_x = SCR_WIDTH / 2.0f;
float last_y = SCR_HEIGHT / 2.0f;
bool first_mouse = true;

float delta_time = 0.0f;
float last_frame = 0.0f;

void processInput(GLFWwindow *window) {
  if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
    glfwSetWindowShouldClose(window, true);
  if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS)
    camera.processKeyboard(UP, delta_time);
  if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS)
    camera.processKeyboard(DOWN, delta_time);
  if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS)
    camera.processKeyboard(LEFT, delta_time);
  if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS)
    camera.processKeyboard(RIGHT, delta_time);
  if (glfwGetKey(window, GLFW_KEY_Q) == GLFW_PRESS)
    camera.processKeyboard(FORWARD, delta_time);
  if (glfwGetKey(window, GLFW_KEY_E) == GLFW_PRESS)
    camera.processKeyboard(BACKWARD, delta_time);
}
void mouseCallback(GLFWwindow *window, double x_pos_in, double y_pos_in) {
  float x_pos = static_cast<float>(x_pos_in);
  float y_pos = static_cast<float>(y_pos_in);

  if (first_mouse) {
    last_x = x_pos;
    last_y = y_pos;
    first_mouse = false;
  }

  float x_offset = x_pos - last_x;
  float y_offset =
      last_y - y_pos; // reversed since y-coordinates go from bottom to top

  last_x = x_pos;
  last_y = y_pos;

  camera.processMouseMovement(x_offset, y_offset);
}
void scrollCallback(GLFWwindow *window, double x_offset, double y_offset) {
  camera.processMouseScroll(static_cast<float>(y_offset));
}
void framebufferSizeCallback(GLFWwindow *window, int width, int height) {
  glViewport(0, 0, width, height);
}
std::string errorName(int err) {
	switch (err) {
#define PER_GL_ERROR(x) case GL_##x: return #x;
		PER_GL_ERROR(NO_ERROR)
			PER_GL_ERROR(INVALID_ENUM)
			PER_GL_ERROR(INVALID_VALUE)
			PER_GL_ERROR(INVALID_OPERATION)
			PER_GL_ERROR(STACK_OVERFLOW)
			PER_GL_ERROR(STACK_UNDERFLOW)
			PER_GL_ERROR(OUT_OF_MEMORY)
	}
	return "unknown error: " + std::to_string(err);
}

int main() {
  /*  init  */
  glfwInit();
  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

  GLFWwindow *window =
      glfwCreateWindow(SCR_WIDTH, SCR_HEIGHT, "Anno", NULL, NULL);
  if (window == NULL) {
    glfwTerminate();
    return -1;
  }
  glfwMakeContextCurrent(window);
  glfwSetFramebufferSizeCallback(window, framebufferSizeCallback);
  glfwSetCursorPosCallback(window, mouseCallback);
  glfwSetScrollCallback(window, scrollCallback);

  if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) {
    glfwTerminate();
  }
  glEnable(GL_DEPTH_TEST);
  
  glm::vec4 position(0, 0, -0.001, 1.0);
  glm::mat4 view = camera.getViewMatrix();
  glm::mat4 projection = glm::perspective(glm::radians(camera.Zoom), 
                                         (float)SCR_WIDTH / (float)SCR_HEIGHT, 0.1f, 100.0f);

  auto result =  projection * position;
  std::cout << result.x << "," << result.y << "," << result.z << "," << result.w << "," << result.z / result.w << std::endl;

  /* prepare data  */
  scene_t scene("../assets/common/cube.scn");

  /*  render  */
  glViewport(0, 0, SCR_WIDTH, SCR_HEIGHT);
  while (!glfwWindowShouldClose(window)) {
    float currentFrame = static_cast<float>(glfwGetTime());
    delta_time = currentFrame - last_frame;
    last_frame = currentFrame;
    processInput(window);

    scene.drawSceneDeferred(camera);
    
    glfwSwapBuffers(window);
    glfwPollEvents();
  }

  glfwTerminate();
  return 0;
}