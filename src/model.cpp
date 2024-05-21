#include <glad/glad.h>
#include <iostream>
#include <stb_image.h>
#include <stb_image_write.h>

#include "model.h"

model_t::model_t(mesh_t *mesh, material_t *material, glm::mat4 transform) {
  this->mesh = mesh;
  this->material = material;
  this->transform = transform;
  config_buffer();
  config_texture();
}

void model_t::config_buffer() {
  glGenVertexArrays(1, &VAO);
  glGenBuffers(1, &VBO);
  float *vertices = new float[mesh->vertices.size() * 8];
  for (int i = 0; i < mesh->vertices.size(); i++) {
    for (int j = 0; j < 3; j++) {
      int index = i * 8 + j;
      vertices[index] = mesh->vertices[i].position[j];
    }
    for (int j = 3; j < 5; j++) {
      int index = i * 8 + j;
      vertices[index] = mesh->vertices[i].texcoord[j - 3];
    }
    for (int j = 5; j < 8; j++) {
      int index = i * 8 + j;
      vertices[index] = mesh->vertices[i].normal[j - 5];
    }
  }
  glBindVertexArray(VAO);
  glBindBuffer(GL_ARRAY_BUFFER, VBO);
  glBufferData(GL_ARRAY_BUFFER, mesh->vertices.size() * 8 * sizeof(float),
               vertices, GL_STATIC_DRAW);
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void *)0);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float),
                        (void *)(3 * sizeof(float)));
  glEnableVertexAttribArray(1);
  glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float),
                        (void *)(5 * sizeof(float)));
  glEnableVertexAttribArray(2);
  glBindVertexArray(0);
}

void model_t::config_texture() {
  if (material->basecolor_map != "null") {
    glGenTextures(1, &basecolor_map);
    int width, height, nrChannels;
    stbi_set_flip_vertically_on_load(1);
    unsigned char *data = stbi_load(material->basecolor_map.c_str(), &width,
                                    &height, &nrChannels, 0);
    glBindTexture(GL_TEXTURE_2D, basecolor_map);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width, height, 0, GL_RGB,
                 GL_UNSIGNED_BYTE, data);
    stbi_image_free(data);
    material->basecolor_factor = glm::vec4(-1.0);
  }
  if (material->metalness_map != "null") {
    glGenTextures(1, &metalness_map);
    int width, height, nrChannels;
    stbi_set_flip_vertically_on_load(1);
    unsigned char *data = stbi_load(material->metalness_map.c_str(), &width,
                                    &height, &nrChannels, 0);
    glBindTexture(GL_TEXTURE_2D, metalness_map);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, width, height, 0, GL_RED,
                 GL_UNSIGNED_BYTE, data);
    stbi_image_free(data);
    material->metalness_factor = -1.0;
  }
  if (material->roughness_map != "null") {
    glGenTextures(1, &roughness_map);
    int width, height, nrChannels;
    stbi_set_flip_vertically_on_load(1);
    unsigned char *data = stbi_load(material->roughness_map.c_str(), &width,
                                    &height, &nrChannels, 0);
    glBindTexture(GL_TEXTURE_2D, roughness_map);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, width, height, 0, GL_RED,
                 GL_UNSIGNED_BYTE, data);
    stbi_image_free(data);
    material->roughness_factor = -1.0;
  }
}

void model_t::draw() {
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, basecolor_map);
  glActiveTexture(GL_TEXTURE1);
  glBindTexture(GL_TEXTURE_2D, metalness_map);
  glActiveTexture(GL_TEXTURE2);
  glBindTexture(GL_TEXTURE_2D, roughness_map);

  glBindVertexArray(VAO);
  glDrawArrays(GL_TRIANGLES, 0, 3 * mesh->num_faces);
}
