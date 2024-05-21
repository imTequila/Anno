#pragma once
#ifndef MESH_H
#define MESH_H

#include <string>
#include <vec2.hpp>
#include <vec3.hpp>
#include <vec4.hpp>
#include <vector>

class vertex_t {
public:
  glm::vec3 position;
  glm::vec2 texcoord;
  glm::vec3 normal;
  glm::vec4 tangent;
  glm::vec4 joint;
  glm::vec4 weight;
};

class mesh_t {
public:
  std::vector<vertex_t> vertices;
  int num_faces;
};

mesh_t *load_mesh(std::string filename);

#endif