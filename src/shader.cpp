#include "shader.hpp"

shader_t::shader_t(const char *vertexPath, const char *fragmentPath,
                   const char *geometryPath) {
  std::string vertex_code;
  std::string fragment_code;
  std::string geometry_code;
  std::ifstream vertex_shader_file;
  std::ifstream fragment_shader_file;
  std::ifstream geometry_shader_file;

  vertex_shader_file.exceptions(std::ifstream::failbit | std::ifstream::badbit);
  fragment_shader_file.exceptions(std::ifstream::failbit | std::ifstream::badbit);
  geometry_shader_file.exceptions(std::ifstream::failbit | std::ifstream::badbit);
  try {

    vertex_shader_file.open(vertexPath);
    fragment_shader_file.open(fragmentPath);
    std::stringstream vertex_shader_stream, fragment_shader_stream;

    vertex_shader_stream << vertex_shader_file.rdbuf();
    fragment_shader_stream << fragment_shader_file.rdbuf();

    vertex_shader_file.close();
    fragment_shader_file.close();

    vertex_code = vertex_shader_stream.str();
    fragment_code = fragment_shader_stream.str();

    if (geometryPath != nullptr) {
      geometry_shader_file.open(geometryPath);
      std::stringstream geometry_shader_stream;
      geometry_shader_stream << geometry_shader_file.rdbuf();
      geometry_shader_file.close();
      geometry_code = geometry_shader_stream.str();
    }
  } catch (std::ifstream::failure &e) {
    std::cout << "ERROR::SHADER::FILE_NOT_SUCCESSFULLY_READ: " << e.what()
              << std::endl;
  }
  const char *vertex_shader_code = vertex_code.c_str();
  const char *fragment_shader_code = fragment_code.c_str();

  unsigned int vertex, fragment;

  vertex = glCreateShader(GL_VERTEX_SHADER);
  glShaderSource(vertex, 1, &vertex_shader_code, NULL);
  glCompileShader(vertex);
  checkCompileErrors(vertex, "VERTEX");

  fragment = glCreateShader(GL_FRAGMENT_SHADER);
  glShaderSource(fragment, 1, &fragment_shader_code, NULL);
  glCompileShader(fragment);
  checkCompileErrors(fragment, "FRAGMENT");

  unsigned int geometry;
  if (geometryPath != nullptr) {
    const char *geometry_shader_code = geometry_code.c_str();
    geometry = glCreateShader(GL_GEOMETRY_SHADER);
    glShaderSource(geometry, 1, &geometry_shader_code, NULL);
    glCompileShader(geometry);
    checkCompileErrors(geometry, "GEOMETRY");
  }
  ID = glCreateProgram();
  glAttachShader(ID, vertex);
  glAttachShader(ID, fragment);
  if (geometryPath != nullptr)
    glAttachShader(ID, geometry);
  glLinkProgram(ID);
  checkCompileErrors(ID, "PROGRAM");
  glDeleteShader(vertex);
  glDeleteShader(fragment);
  if (geometryPath != nullptr)
    glDeleteShader(geometry);
}

shader_t::shader_t() {

}

void shader_t::use() { glUseProgram(ID); }

void shader_t::setBool(const std::string &name, bool value) const {
  glUniform1i(glGetUniformLocation(ID, name.c_str()), (int)value);
}

void shader_t::setInt(const std::string &name, int value) const {
  glUniform1i(glGetUniformLocation(ID, name.c_str()), value);
}

void shader_t::setFloat(const std::string &name, float value) const {
  glUniform1f(glGetUniformLocation(ID, name.c_str()), value);
}

void shader_t::setVec2(const std::string &name, const glm::vec2 &value) const {
  glUniform2fv(glGetUniformLocation(ID, name.c_str()), 1, &value[0]);
}

void shader_t::setVec2(const std::string &name, float x, float y) const {
  glUniform2f(glGetUniformLocation(ID, name.c_str()), x, y);
}

void shader_t::setVec3(const std::string &name, const glm::vec3 &value) const {
  glUniform3fv(glGetUniformLocation(ID, name.c_str()), 1, &value[0]);
}

void shader_t::setVec3(const std::string &name, float x, float y,
                       float z) const {
  glUniform3f(glGetUniformLocation(ID, name.c_str()), x, y, z);
}

void shader_t::setVec4(const std::string &name, const glm::vec4 &value) const {
  glUniform4fv(glGetUniformLocation(ID, name.c_str()), 1, &value[0]);
}

void shader_t::setVec4(const std::string &name, float x, float y, float z,
                       float w) const {
  glUniform4f(glGetUniformLocation(ID, name.c_str()), x, y, z, w);
}

void shader_t::setMat2(const std::string &name, const glm::mat2 &mat) const {
  glUniformMatrix2fv(glGetUniformLocation(ID, name.c_str()), 1, GL_FALSE,
                     &mat[0][0]);
}

void shader_t::setMat3(const std::string &name, const glm::mat3 &mat) const {
  glUniformMatrix3fv(glGetUniformLocation(ID, name.c_str()), 1, GL_FALSE,
                     &mat[0][0]);
}

void shader_t::setMat4(const std::string &name, const glm::mat4 &mat) const {
  glUniformMatrix4fv(glGetUniformLocation(ID, name.c_str()), 1, GL_FALSE,
                     &mat[0][0]);
}

void shader_t::checkCompileErrors(GLuint shader, std::string type) {
  GLint success;
  GLchar info_log[1024];
  if (type != "PROGRAM") {
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (!success) {
      glGetShaderInfoLog(shader, 1024, NULL, info_log);
      std::cout
          << "ERROR::SHADER_COMPILATION_ERROR of type: " << type << "\n"
          << info_log
          << "\n -- --------------------------------------------------- -- "
          << std::endl;
    }
  } else {
    glGetProgramiv(shader, GL_LINK_STATUS, &success);
    if (!success) {
      glGetProgramInfoLog(shader, 1024, NULL, info_log);
      std::cout
          << "ERROR::PROGRAM_LINKING_ERROR of type: " << type << "\n"
          << info_log
          << "\n -- --------------------------------------------------- -- "
          << std::endl;
    }
  }
}